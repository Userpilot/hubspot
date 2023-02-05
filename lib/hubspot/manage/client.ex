defmodule Hubspot.Manage.Client do
  @moduledoc """
  This module is used to manage all hubspot Clients API calls
  for example: Contact/Company properties, contacts/companies syncing
  """

  alias Hubspot.Common.API
  alias Hubspot.Auth.Manage.Token

  @doc """
  list all client's object(contact, company) properties
  """
  @spec list_custom_properties(String.t(), String.t(), :contact | :company) ::
          {:ok, list()} | {:error, map()}
  def list_custom_properties(client_code, refresh_token, object_type)
      when object_type in [:contact, :company] do
    Token.get_client_access_token(client_code, refresh_token)
    |> case do
      {:ok, token} ->
        API.request(
          :get,
          "crm/v3/properties/#{object_type}",
          nil,
          [{"Content-type", "application/json"}, {"authorization", "Bearer #{token}"}, {"accept", "application/json"}]
        )
        |> case do
          {:ok, %{status: status, body: body}} ->
            {:ok, %{status: status, body: Enum.map(body["results"], &to_property/1)}}

          {:error, body} ->
            {:error, body}
        end

      {:not_found, reason} ->
        {:error, reason}
    end
  end

  def list_custom_properties(_client_code, _refresh_token, _object_type),
    do: {:error, "only :contact or :company objects are supported"}

  @doc """
  Get client info
  """
  @spec get_client_info(String.t(), String.t()) :: {:ok, map()} | {:error, map()}
  def get_client_info(client_code, refresh_token) do
    Token.get_client_access_token(client_code, refresh_token)
    |> case do
      {:ok, token} ->
        API.request(
          :get,
          "/account-info/v3/details",
          nil,
          [{"Content-type", "application/json"}, {"authorization", "Bearer #{token}"}, {"accept", "application/json"}]
        )

      {:not_found, reason} ->
        {:error, reason}
    end
  end

  @doc """
  Send a hubspot event to the specified event template id
  you can either use object_id or email as the contact identifier
  """
  @spec send_event(String.t(), String.t(), Atom.t(), String.t(), map(), keyword()) ::
          {:ok, map()} | {:error, map()}
  def send_event(client_code, refresh_token, :object_id, template_id, params, object_id) do
    Token.get_client_access_token(client_code, refresh_token)
    |> case do
      {:ok, token} ->
        API.request(
          :post,
          "/crm/v3/timeline/events",
          Jason.encode!(%{
            eventTemplateId: template_id,
            objectId: object_id,
            tokens: params
          }),
          [{"Content-type", "application/json"}, {"authorization", "Bearer #{token}"}, {"accept", "application/json"}]
        )

      {:not_found, reason} ->
        {:error, reason}
    end
  end

  def send_event(client_code, refresh_token, :email, template_id, params, email) do
    Token.get_client_access_token(client_code, refresh_token)
    |> case do
      {:ok, token} ->
        API.request(
          :post,
          "/crm/v3/timeline/events",
          Jason.encode!(%{
            eventTemplateId: template_id,
            email: email,
            tokens: params
          }),
          [{"Content-type", "application/json"}, {"authorization", "Bearer #{token}"}, {"accept", "application/json"}]
        )

      {:not_found, reason} ->
        {:error, reason}
    end
  end

  defp to_property(property),
    do: %{
      name: property["name"],
      label: property["label"],
      hubspot_defined: property["hubspotDefined"]
    }

  @doc """
  list all client's object(contact, company) properties
  """
  @spec get_contact_by_email(String.t(), String.t(), String.t()) ::
          {:ok, map()} | {:error, map()}
  def get_contact_by_email(client_code, refresh_token, email) do
    Token.get_client_access_token(client_code, refresh_token)
    |> case do
      {:ok, token} ->
        API.request(
          :get,
          "crm/v3/objects/contacts/#{email}?idProperty=email",
          nil,
          [{"content-type", "application/json"}, {"authorization", "Bearer #{token}"}, {"accept", "application/json"}]
        )

      {:not_found, reason} ->
        {:error, reason}
    end
  end

  @doc """
  get object(:contact,:company) by id
  """
  @spec get_object_by_id(String.t(), String.t(), :contact | :company, String.t()) ::
          {:ok, map()} | {:error, map()}
  def get_object_by_id(client_code, refresh_token, object_type, object_id) do
    Token.get_client_access_token(client_code, refresh_token)
    |> case do
      {:ok, token} ->
        API.request(
          :get,
          "crm/v3/objects/#{to_object_type(object_type)}/#{object_id}",
          nil,
          [{"Content-type", "application/json"}, {"authorization", "Bearer #{token}"}, {"accept", "application/json"}]
        )

      {:not_found, reason} ->
        {:error, reason}
    end
  end

  @doc """
  Get all objects(contact,company) matching the property_name,propery_value
  """
  @spec get_object_by_property(
          String.t(),
          String.t(),
          :contact | :company,
          String.t(),
          String.t()
        ) ::
          {:ok, map()} | {:error, map()}
  def get_object_by_property(
        client_code,
        refresh_token,
        object_type,
        property_name,
        property_value
      )
      when object_type in [:contact, :company] do
    Token.get_client_access_token(client_code, refresh_token)
    |> case do
      {:ok, token} ->
        API.request(
          :post,
          "crm/v3/objects/#{object_type}/search",
          Jason.encode!(%{
            filterGroups: [
              %{
                filters: [
                  %{
                    propertyName: property_name,
                    operator: "EQ",
                    value: property_value
                  }
                ]
              }
            ]
          }),
          [{"Content-type", "application/json"}, {"authorization", "Bearer #{token}", {"accept", "application/json"}}]
        )

      {:not_found, reason} ->
        {:error, reason}
    end
  end

  defp to_object_type(:contact), do: "contacts"
  defp to_object_type(:company), do: "companies"
end
