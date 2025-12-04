defmodule Hubspot.Manage.PrivateClient do
  alias Hubspot.Common.API

  @valid_types [:user, :organization, :application]
  @json_headers [
    {"content-type", "application/json"},
    {"accept", "application/json"}
  ]

  def request(access_token, post_type, object_type, object, opts \\ [])

  def request(access_token, post_type, object_type, %{inputs: _objects} = payload, opts)
      when object_type in @valid_types do
    custom_object = custom_object(object_type, opts[:object_prefix])
    headers = [{"authorization", "Bearer " <> access_token} | @json_headers]
    body = Jason.encode!(payload)
    url = "crm/v3/objects/#{custom_object}/batch/#{post_type}"

    send_request(:post, url, body, headers)
  end

  def request(access_token, method, :association, %{inputs: _objects} = payload, opts) do
    from_object = custom_object(opts[:from_type], opts[:object_prefix])
    to_object = custom_object(opts[:to_type], opts[:object_prefix])
    url = "/crm/v3/associations/#{from_object}/#{to_object}/batch/#{method}"
    headers = [{"authorization", "Bearer " <> access_token} | @json_headers]
    body = Jason.encode!(payload)

    send_request(:post, url, body, headers)
  end

  def request(
        access_token,
        :create,
        :association,
        %{from_id: from_id, to_id: to_id, association_type: association_type},
        opts
      ) do
    from_object = custom_object(opts[:from_type], opts[:object_prefix])
    to_object = custom_object(opts[:to_type], opts[:object_prefix])

    url =
      "/crm/v3/objects/#{from_object}/#{from_id}/associations/#{to_object}/#{to_id}/#{association_type}"

    headers = [{"authorization", "Bearer " <> access_token} | @json_headers]

    send_request(:put, url, "", headers)
  end

  def request(access_token, :get, object_type, %{id: id}, opts)
      when object_type in @valid_types do
    custom_object = custom_object(object_type, opts[:object_prefix])
    headers = [{"authorization", "Bearer " <> access_token} | @json_headers]
    url = "crm/v3/objects/#{custom_object}/#{id}?idProperty=#{id_property(object_type)}"

    send_request(:get, url, nil, headers)
  end

  def request(access_token, :create, object_type, object, opts)
      when object_type in @valid_types do
    custom_object = custom_object(object_type, opts[:object_prefix])
    headers = [{"authorization", "Bearer " <> access_token} | @json_headers]
    url = "crm/v3/objects/#{custom_object}"
    body = Jason.encode!(object)

    send_request(:post, url, body, headers)
  end

  def request(access_token, :update, object_type, object, opts)
      when object_type in @valid_types do
    custom_object = custom_object(object_type, opts[:object_prefix])
    headers = [{"authorization", "Bearer " <> access_token} | @json_headers]
    url = "crm/v3/objects/#{custom_object}/#{object.id}?idProperty=#{id_property(object_type)}"
    body = Jason.encode!(object)

    send_request(:patch, url, body, headers)
  end

  def request(_access_token, method, object_type, _object, _opts),
    do:
      {:error,
       "unsupported request method #{inspect(method)}, object_type #{inspect(object_type)}"}

  defp send_request(method, url, body, headers) do
    case API.request(method, url, body, headers) do
      {:ok, %{status: _status, body: body}} -> {:ok, body}
      {:error, %{status: 404}} -> {:error, :not_found}
      error -> error
    end
  end

  # ------------------------------------------------------------
  # Object Type Mapping
  # ------------------------------------------------------------

  defp custom_object(:user, object_prefix), do: "#{object_prefix}_users"
  defp custom_object(:organization, object_prefix), do: "#{object_prefix}_organizations"
  defp custom_object(:application, object_prefix), do: "#{object_prefix}_applications"

  defp id_property(:organization), do: "id"
  defp id_property(:application), do: "application_id"
  defp id_property(:user), do: "email"
end
