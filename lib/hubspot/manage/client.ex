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
    with {:ok, token} <- Token.get_client_access_token(client_code, refresh_token),
         {:ok, %{status: status, body: body}} <-
           API.request(
             :get,
             "crm/v3/properties/#{object_type}",
             nil,
             [
               {"Content-type", "application/json"},
               {"authorization", "Bearer #{token}"},
               {"accept", "application/json"}
             ]
           ) do
      {:ok, %{status: status, body: Enum.map(body["results"], &to_property/1)}}
    else
      {:not_found, reason} ->
        {:error, reason}

      error ->
        error
    end
  end

  def list_custom_properties(_client_code, _refresh_token, _object_type),
    do: {:error, "only :contact or :company objects are supported"}

  @doc """
  Get client info
  """
  @spec get_client_info(String.t(), String.t()) :: {:ok, map()} | {:error, map()}
  def get_client_info(client_code, refresh_token) do
    client_code
    |> Token.get_client_access_token(refresh_token)
    |> case do
      {:ok, token} ->
        API.request(
          :get,
          "/account-info/v3/details",
          nil,
          [
            {"Content-type", "application/json"},
            {"authorization", "Bearer #{token}"},
            {"accept", "application/json"}
          ]
        )

      {:not_found, reason} ->
        {:error, reason}
    end
  end

  @doc """
  Send a hubspot event to the specified event template id
  you can either use object_id or email as the contact identifier
  """
  @spec send_event(String.t(), String.t(), :object_id | :email, String.t(), map(), keyword()) ::
          {:ok, map()} | {:error, map()}
  def send_event(client_code, refresh_token, :object_id, template_id, params, object_id) do
    client_code
    |> Token.get_client_access_token(refresh_token)
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
          [
            {"Content-type", "application/json"},
            {"authorization", "Bearer #{token}"},
            {"accept", "application/json"}
          ]
        )

      {:not_found, reason} ->
        {:error, reason}
    end
  end

  def send_event(client_code, refresh_token, :email, template_id, params, email) do
    client_code
    |> Token.get_client_access_token(refresh_token)
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
          [
            {"Content-type", "application/json"},
            {"authorization", "Bearer #{token}"},
            {"accept", "application/json"}
          ]
        )

      {:not_found, reason} ->
        {:error, reason}
    end
  end

  defp to_property(property),
    do: %{
      id: property["name"],
      title: property["label"],
      hubspot_defined: property["hubspotDefined"]
    }

  @doc """
  list all client's object(contact, company) properties
  """
  @spec get_contact_by_email(String.t(), String.t(), String.t()) ::
          {:ok, map()} | {:error, map()}
  def get_contact_by_email(client_code, refresh_token, email) do
    client_code
    |> Token.get_client_access_token(refresh_token)
    |> case do
      {:ok, token} ->
        API.request(
          :get,
          "crm/v3/objects/contacts/#{email}?idProperty=email",
          nil,
          [
            {"content-type", "application/json"},
            {"authorization", "Bearer #{token}"},
            {"accept", "application/json"}
          ]
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
    client_code
    |> Token.get_client_access_token(refresh_token)
    |> case do
      {:ok, token} ->
        API.request(
          :get,
          "crm/v3/objects/#{to_object_type(object_type)}/#{object_id}",
          nil,
          [
            {"Content-type", "application/json"},
            {"authorization", "Bearer #{token}"},
            {"accept", "application/json"}
          ]
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
    client_code
    |> Token.get_client_access_token(refresh_token)
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
          [
            {"Content-type", "application/json"},
            {"authorization", "Bearer #{token}", {"accept", "application/json"}}
          ]
        )

      {:not_found, reason} ->
        {:error, reason}
    end
  end

  @doc """
  Read list of hubspot objects(contacts/companies)

  Given client's auth creddentials(clinet_code,refresh_token),
  page_size,after_token(token returned by previous call for
  next page), and properties(list of properties returned for each
  object), the function will return a list of non-archived objects.
  """
  @spec list_objects(
          String.t(),
          String.t(),
          :contact | :company,
          String.t(),
          String.t() | nil,
          list()
        ) ::
          {:ok, list()} | {:error, map()}
  def list_objects(client_code, refresh_token, object_type, page_size, after_token, properties)
      when object_type in [:contact, :company] do
    query_params =
      to_query_params_string(
        limit: page_size,
        after: after_token,
        properties: to_properties_string(properties)
      )

    with {:ok, token} <- Token.get_client_access_token(client_code, refresh_token),
         {:ok, %{status: status, body: body}} <-
           API.request(
             :get,
             "crm/v3/objects/#{to_object_type(object_type)}?#{query_params}",
             nil,
             [
               {"Content-type", "application/json"},
               {"authorization", "Bearer #{token}"},
               {"accept", "application/json"}
             ]
           ) do
      {:ok, %{status: status, body: body}}
    else
      {:not_found, reason} ->
        {:error, reason}

      error ->
        error
    end
  end

  defp to_object_type(:contact), do: "contacts"
  defp to_object_type(:company), do: "companies"

  defp to_properties_string(properties), do: Enum.join(properties, ", ")

  defp to_query_params_string(params) do
    params
    |> Enum.reject(fn {_key, val} -> is_nil(val) end)
    |> Enum.map_join("&", fn {key, val} -> "#{key}=#{val}" end)
  end
end
