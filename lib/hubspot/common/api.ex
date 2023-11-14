defmodule Hubspot.Common.API do
  use Hubspot.Common.Config

  @default_transport_retry_timeout 1_000

  require Logger

  def request(type, url, body \\ nil, headers \\ [], opts \\ []) do
    opts = Keyword.merge([receive_timeout: 6_000], opts)

    case :timer.tc(&do_send_request/5, [type, url, body, headers, opts]) do
      {time, {:ok, response}} ->
        {:ok, Map.put(response, :time, time)}

      {time, {:error, error}} ->
        {:error, Map.put(error, :time, time)}
    end
  end

  defp do_send_request(
         type,
         url,
         body,
         headers,
         opts,
         start_time \\ :erlang.monotonic_time(:millisecond)
       ) do
    type
    |> Finch.build(Path.join(config(:http_api), url), headers, body)
    |> Finch.request(__MODULE__, opts)
    # WA for Random socket closed issue https://github.com/sneako/finch/issues/62
    |> case do
      {:error, %Mint.TransportError{reason: _reason} = error} ->
        transport_retry_timeout =
          Keyword.get(opts, :transport_retry_timeout, @default_transport_retry_timeout)

        if :erlang.monotonic_time(:millisecond) < start_time + transport_retry_timeout do
          # Wait for 10ms before retrying
          :timer.sleep(10)
          do_send_request(type, url, body, headers, opts, start_time)
        else
          {:error, error}
        end

      {status, response} ->
        decode_response({status, response})
    end
  end

  defp decode_response({:ok, %Finch.Response{status: _status, body: _body} = response}),
    do: decode_response(response)

  defp decode_response({:error, %Finch.Error{__exception__: exception, reason: reason}}),
    do:
      {:error,
       %{status: nil, body: "#{reason}: #{Exception.format(:error, exception)}", headers: nil}}

  defp decode_response({:error, %Mint.TransportError{reason: reason} = error}),
    do: {:error, %{status: nil, body: "#{reason}: #{Exception.message(error)}", headers: nil}}

  defp decode_response(%Finch.Response{status: status, body: body, headers: headers} = _response)
       when status >= 200 and status < 300,
       do: {:ok, %{status: status, body: Jason.decode!(body), headers: headers}}

  # Hubspot API returns xml for 404 response, so we can't decode it and we need to treat it differently(soft error)
  defp decode_response(%Finch.Response{status: status, body: body, headers: headers} = _response)
       when status == 404,
       do: {:error, %{status: status, body: body, headers: headers}}

  defp decode_response(%Finch.Response{status: status, body: body, headers: headers} = _response),
    do: {:error, %{status: status, body: Jason.decode!(body), headers: headers}}
end
