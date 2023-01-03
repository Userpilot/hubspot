defmodule Hubspot.Auth.Manage.Token do
  alias Hubspot.Common.API
  require Logger

  use Hubspot.Common.Config

  @ttl :timer.seconds(1_800)

  # Hubspot clients are identified by their code(returned after initial authentication flow)
  @spec get_client_access_token(any, any) :: {:not_found, any} | {:ok, any}
  def get_client_access_token(client_code, refresh_token) do
    Cachex.fetch(:hubspot_cache, client_code, fn key ->
      Logger.info(
        "Hubspot Cache key '#{key}' not found, running fallback for hubspot access token"
      )

      case generate_new_access_token(refresh_token) do
        {:ok, %{"access_token" => access_token}} ->
          Cachex.expire(:hubspot_cache, client_code, :timer.seconds(@ttl))

          {:commit, access_token}

        _ ->
          {:ignore,
           "Failed to generate an access token for Hubspot OAuth management API for client with code #{client_code}"}
      end
    end)
    |> maybe_set_cache(client_code)
    |> normalize_cache_fetch()
  end

  # This API will return access_token, refresh_token, and expiration info for the client
  def authenticate_client(client_code) do
    req_body =
      URI.encode_query(%{
        grant_type: "authorization_code",
        client_id: config(:client_id),
        client_secret: config(:client_secret),
        redirect_uri: config(:redirect_uri),
        code: client_code
      })

    API.request(
      :post,
      "/oauth/v1/token",
      req_body,
      [
        {"content-type", "application/x-www-form-urlencoded"}
      ]
    )
    |> normalize_api_response()
  end

  def generate_new_access_token(refresh_token) do
    API.request(
      :post,
      "/oauth/v1/token",
      URI.encode_query(%{
        grant_type: "refresh_token",
        client_id: config(:client_id),
        client_secret: config(:client_secret),
        refresh_token: refresh_token
      }),
      [
        {"Content-Type", "application/x-www-form-urlencoded"}
      ]
    )
    |> normalize_api_response()
  end

  # `Cachex.fetch/4` doesn't allow for setting TTL
  # in case of commit though we want to set TTL
  # so in commit case we set TTL on the key
  #
  # https://github.com/whitfin/cachex/issues/195
  #
  defp maybe_set_cache({:commit, _} = response, client_code) do
    Cachex.expire(:hubspot_cache, client_code, :timer.seconds(@ttl))

    response
  end

  defp maybe_set_cache(response, _), do: response

  defp normalize_cache_fetch(response) do
    case response do
      {:ignore, reason} ->
        {:not_found, reason}

      {_status, cached} ->
        {:ok, cached}
    end
  end

  defp normalize_api_response({status, %{body: body}}), do: {status, body}
end
