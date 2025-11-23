defmodule Hubspot.Manage.PrivateClient do
  alias Hubspot.Common.API
  @object_prefix "p4160154_"

  def request(access_token, post_type, object_type, object, opts \\ [])

  def request(access_token, post_type, object_type, %{inputs: _objects} = payload, opts)
      when object_type in [:user, :organization, :application] do
    case API.request(
           :post,
           "crm/v3/objects/#{to_object_type(object_type)}/batch/#{post_type}",
           Jason.encode!(payload),
           [
             {"Content-type", "application/json"},
             {"authorization", "Bearer #{access_token}"},
             {"accept", "application/json"}
           ]
         ) do
      {:ok, %{status: status, body: body}} -> {:ok, body}
      {:error, %{status: 404}} -> {:error, :not_found}
      error -> error
    end
  end

  def request(access_token, method, :association, %{inputs: _objects} = payload, opts) do
    case API.request(
           :post,
           "/crm/v3/associations/#{to_object_type(opts[:from_type])}/#{to_object_type(opts[:to_type])}/batch/#{method}",
           Jason.encode!(payload),
           [
             {"authorization", "Bearer #{access_token}"},
             {"accept", "application/json"},
             {"Content-Type", "application/json"}
           ]
         ) do
      {:ok, %{status: status, body: body}} -> {:ok, body}
      {:error, %{status: 404}} -> {:error, :not_found}
      error -> error
    end
  end

  def request(access_token, :get, object_type, object, opts)
      when object_type in [:user, :organization, :application] do
    case API.request(
           :get,
           "crm/v3/objects/#{to_object_type(object_type)}/#{object.id}?idProperty=#{id_property(object_type)}",
           nil,
           [
             {"authorization", "Bearer #{access_token}"},
             {"accept", "application/json"},
             {"Content-Type", "application/json"}
           ]
         ) do
      {:ok, %{status: status, body: body}} -> {:ok, body}
      {:error, %{status: 404}} -> {:error, :not_found}
      error -> error
    end
  end

  def request(access_token, :create, object_type, object, opts)
      when object_type in [:user, :organization, :application] do
    case API.request(
           :post,
           "crm/v3/objects/#{to_object_type(object_type)}",
           Jason.encode!(object),
           [
             {"authorization", "Bearer #{access_token}"},
             {"accept", "application/json"},
             {"Content-Type", "application/json"}
           ]
         ) do
      {:ok, %{status: status, body: body}} -> {:ok, body}
      {:error, %{status: 404}} -> {:error, :not_found}
      error -> error
    end
  end

  def request(access_token, :update, object_type, object, opts)
      when object_type in [:user, :organization, :application] do
    case API.request(
           :patch,
           "crm/v3/objects/#{to_object_type(object_type)}/#{object.id}?idProperty=#{id_property(object_type)}",
           Jason.encode!(object),
           [
             {"authorization", "Bearer #{access_token}"},
             {"accept", "application/json"},
             {"Content-Type", "application/json"}
           ]
         ) do
      {:ok, %{status: status, body: body}} -> {:ok, body}
      {:error, %{status: 404}} -> {:error, :not_found}
      error -> error
    end
  end

  def request(_client_code, _access_token, object_type, _objects, _opts),
    do: {:error, "unsupported object_type #{inspect(object_type)}"}

  # ------------------------------------------------------------
  # Object Type Mapping
  # ------------------------------------------------------------
  defp to_object_type(type) , do: "#{@object_prefix}#{to_string(type)}s"
  defp id_property(:organization), do: "id"
  defp id_property(:application), do: "application_id"
  defp id_property(:user), do: "email"
end
