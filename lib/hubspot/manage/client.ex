defmodule Hubspot.Manage.Client do
  @moduledoc """
  This module is used to manage all hubspot Clients API calls
  for example: Contact/Company properties, contacts/companies syncing
  """

  alias Hubspot.Common.API
  alias Hubspot.Auth.Manage.Token
  alias Hubspot.Common.Helpers

  @doc """
  list all client's object(contact, company) properties
  """
  @spec list_custom_properties(String.t(), String.t(), :contact | :company) ::
          {:ok, list()} | {:error, map()}
  def list_custom_properties(client_code, refresh_token, object_type)
      when object_type in [:contact, :property] do
    {:ok, token} = Token.get_client_access_token(client_code, refresh_token)

    API.request(
      :get,
      "crm/v3/properties/#{Atom.to_string(object_type)}",
      nil,
      [{"Content-type", "application/json"}, {"authorization", "Bearer #{token}"}]
    )
    |> Helpers.normalize_api_response()
    |> case do
      {:ok, body} -> {:ok, Enum.map(body["results"], &to_property/1)}
      {:error, body} -> {:error, body}
    end
  end

  @doc """
  Get client info
  """
  @spec get_client_info(String.t(), String.t()) :: {:ok,list()} | {:error,map()}
  def get_client_info(client_code, refresh_token) do
    {:ok, token} = Token.get_client_access_token(client_code, refresh_token)

    API.request(
      :get,
      "/account-info/v3/details",
      nil,
      [{"Content-type", "application/json"}, {"authorization", "Bearer #{token}"}]
    )
    |> Helpers.normalize_api_response()
  end

  defp to_property(property),
    do: %{
      name: property["name"],
      label: property["label"],
      hubspot_defined: property["hubspotDefined"]
    }
end
