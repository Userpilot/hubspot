defmodule Hubspot.Manage.Client do
  @moduledoc """
  This module is used to manage all hubspot Clients API calls
  for example: Contact/Company properties, contacts/companies syncing
  """

  alias Hubspot.Common.API
  alias Hubspot.Auth.Manage.Token

  @primary_standard_objects_ids %{
    "0-1" => "contact",
    "0-2" => "company",
    "0-3" => "deal",
    "0-5" => "ticket"
  }

  @primary_standard_objects_ids_map %{
    "contact" => "0-1",
    "company" => "0-2",
    "deal" => "0-3",
    "ticket" => "0-5"
  }

  # This needs to build an API function working with standard object and custom object ones
  @standard_objects_types [
    :contact,
    :company,
    :deal,
    :ticket
  ]

  @plural_objects_types [
    "contacts",
    "companies",
    "deals",
    "tickets"
  ]

  @standard_objects_types_map %{
    contact: "contacts",
    company: "companies",
    deal: "deals",
    ticket: "tickets"
  }
  @type standard_objects :: unquote(Enum.reduce(@standard_objects_types, &{:|, [], [&1, &2]}))

  @doc """
  To get from Hubspot side the metadata information about some property, like the fieldType, etc ..
  """
  @spec get_custom_property_metadata(String.t(), String.t(), standard_objects, String.t()) ::
          {:ok, map()} | {:error, map()}
  def get_custom_property_metadata(client_code, refresh_token, object_type, property_name)
      when object_type in @standard_objects_types do
    with {:ok, token} <- Token.get_client_access_token(client_code, refresh_token),
         {:ok, %{status: status, body: body}} <-
           API.request(
             :get,
             "crm/v3/properties/#{object_type}/#{property_name}",
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

  @doc """
  list all client's object(contact, company) properties
  """
  @spec list_custom_properties(String.t(), String.t(), standard_objects) ::
          {:ok, list()} | {:error, map()}
  def list_custom_properties(client_code, refresh_token, object_type)
      when object_type in @standard_objects_types do
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
          "/oauth/v1/access-tokens/#{token}",
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
            email: String.trim(email),
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

  @doc """
  list all client's object(contact, company) properties
  """
  @spec get_contact_by_email(String.t(), String.t(), String.t()) ::
          {:ok, map()} | {:error, map()}
  def get_contact_by_email(client_code, refresh_token, email, properties \\ []) do
    client_code
    |> Token.get_client_access_token(refresh_token)
    |> case do
      {:ok, token} ->
        API.request(
          :get,
          "crm/v3/objects/contacts/#{String.trim(email)}?idProperty=email&properties=#{to_properties_string(properties)}",
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
  @spec get_object_by_id(String.t(), String.t(), :contact | :company, String.t(), list()) ::
          {:ok, map()} | {:error, map()}
  def get_object_by_id(client_code, refresh_token, object_type, object_id, properties) do
    client_code
    |> Token.get_client_access_token(refresh_token)
    |> case do
      {:ok, token} ->
        query_params = to_query_params_string(properties: to_properties_string(properties))

        API.request(
          :get,
          "crm/v3/objects/#{to_object_type(object_type)}/#{object_id}?#{query_params}",
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
  Get all objects(contact,company) matching the property_name, property_values, and last modified date >= last_modified_date_timestamp
  By default, the search endpoints will return pages of 10 records at a time.
  This can be changed by setting the limit parameter in the request body.
  The maximum number of supported objects per page is 100.
  """
  @spec get_objects_by_property_values(
          String.t(),
          String.t(),
          standard_objects,
          String.t(),
          list(),
          String.t(),
          list(),
          number()
        ) ::
          {:ok, map()} | {:error, map()}
  def get_objects_by_property_values(
        client_code,
        refresh_token,
        object_type,
        next_token,
        properties,
        property_name,
        property_values,
        limit \\ 10
      )
      when object_type in @standard_objects_types do
    client_code
    |> Token.get_client_access_token(refresh_token)
    |> case do
      {:ok, token} ->
        values_filters = [
          %{
            propertyName: property_name,
            operator: "HAS_PROPERTY"
          },
          %{
            propertyName: property_name,
            operator: "IN",
            values: property_values
          }
        ]

        request_body = %{
          after: parse_after_token(next_token),
          limit: Integer.to_string(limit),
          properties: properties,
          filterGroups: [
            %{
              filters: values_filters
            }
          ]
        }

        API.request(
          :post,
          "crm/v3/objects/#{object_type}/search",
          Jason.encode!(request_body),
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

  defp parse_after_token(nil), do: ""
  defp parse_after_token(token), do: token

  @doc """
  Get all objects(contact, company) matching the property_name, property_value
  """
  @spec get_object_by_property(
          String.t(),
          String.t(),
          standard_objects,
          String.t(),
          String.t()
        ) ::
          {:ok, map()} | {:error, map()}
  def get_object_by_property(
        client_code,
        refresh_token,
        object_type,
        property_name,
        property_value,
        properties \\ []
      )
      when object_type in @standard_objects_types do
    client_code
    |> Token.get_client_access_token(refresh_token)
    |> case do
      {:ok, token} ->
        API.request(
          :post,
          "crm/v3/objects/#{object_type}/search",
          Jason.encode!(%{
            properties: properties,
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
            {"authorization", "Bearer #{token}"},
            {"accept", "application/json"}
          ]
        )

      {:not_found, reason} ->
        {:error, reason}
    end
  end

  @doc """
  Read list of hubspot objects(contacts/companies)

  Given client's auth credentials(client_code,refresh_token),
  page_size,after_token(token returned by previous call for
  next page), and properties(list of properties returned for each
  object), the function will return a list of non-archived objects.
  """
  @spec list_objects(
          String.t(),
          String.t(),
          standard_objects,
          String.t(),
          String.t() | nil,
          list()
        ) ::
          {:ok, map()} | {:error, map()}
  def list_objects(client_code, refresh_token, object_type, page_size, after_token, properties)
      when object_type in @standard_objects_types do
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

  @spec discovery_custom_objects(String.t(), String.t()) :: {:ok, map()} | {:error, map()}
  def discovery_custom_objects(client_code, refresh_token) do
    with {:ok, token} <- Token.get_client_access_token(client_code, refresh_token),
         {:ok, %{status: status, body: body}} <-
           API.request(
             :get,
             "crm/v3/schemas",
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

  @spec discovery_objects(String.t(), String.t()) :: {:ok, map()} | {:error, map()}
  def discovery_objects(client_code, refresh_token) do
    with {:ok, token} <- Token.get_client_access_token(client_code, refresh_token),
         {:ok, %{status: status, body: body}} <-
           API.request(
             :get,
             "crm/v3/schemas",
             nil,
             [
               {"Content-type", "application/json"},
               {"authorization", "Bearer #{token}"},
               {"accept", "application/json"}
             ]
           ) do
      {:ok,
       %{
         status: status,
         body: Enum.map(body["results"], &to_custom_object/1) ++ bind_standard_objects()
       }}
    else
      {:not_found, reason} ->
        {:error, reason}

      error ->
        error
    end
  end

  @spec get_object_properties(String.t(), String.t(), String.t()) ::
          {:ok, map()} | {:error, map()}
  def get_object_properties(client_code, refresh_token, object_name) do
    with {:ok, token} <- Token.get_client_access_token(client_code, refresh_token),
         {:ok, %{status: status, body: body}} <-
           API.request(
             :get,
             "crm/v3/schemas/#{maybe_alter_object_name(object_name)}",
             nil,
             [
               {"Content-type", "application/json"},
               {"authorization", "Bearer #{token}"},
               {"accept", "application/json"}
             ]
           ) do
      {:ok, %{status: status, body: Enum.map(body["properties"], &to_property/1)}}
    else
      {:not_found, reason} ->
        {:error, reason}

      error ->
        error
    end
  end

  @spec get_related_custom_events(String.t(), String.t(), keyword()) ::
          {:ok, map()} | {:error, map()}
  def get_related_custom_events(client_code, refresh_token, opts \\ []) do
    search_term = Keyword.get(opts, :search_term, "")
    include_properties = Keyword.get(opts, :include_properties, false)

    with {:ok, token} <- Token.get_client_access_token(client_code, refresh_token),
         {:ok, %{status: status, body: body}} <-
           API.request(
             :get,
             "events/v3/event-definitions?searchString=#{search_term}&includeProperties=#{include_properties}",
             nil,
             [
               {"Content-type", "application/json"},
               {"authorization", "Bearer #{token}"},
               {"accept", "application/json"}
             ]
           ),
         custom_event_names_mapping <-
           maybe_build_custom_event_names_mapping(client_code, refresh_token, opts) do
      {:ok,
       %{
         status: status,
         body:
           Enum.map(body["results"], fn event ->
             event
             |> maybe_add_standard_object_name()
             |> maybe_add_custom_event_name(custom_event_names_mapping)
           end)
       }}
    end
  end

  defp bind_standard_objects(),
    do:
      @standard_objects_types
      |> Enum.map(fn object_name ->
        %{
          fully_qualified_name: @standard_objects_types_map[object_name],
          singular_name: to_string(object_name),
          plural_name: @standard_objects_types_map[object_name],
          is_standard_object: true,
          primary_object_id: @primary_standard_objects_ids_map[to_string(object_name)]
        }
      end)

  defp to_custom_object(object) do
    %{
      fully_qualified_name: object["fullyQualifiedName"],
      singular_name: object["labels"]["singular"],
      plural_name: object["labels"]["plural"],
      primary_object_id: object["objectTypeId"],
      type: "custom_object"
    }
  end

  defp to_object_type(object_type) when object_type in @standard_objects_types,
    do: to_string(object_type)

  defp to_object_type(object_type), do: raise("Invalid object type: #{inspect(object_type)}")

  defp to_properties_string(properties), do: Enum.join(properties, ",")

  defp to_query_params_string(params) do
    params
    |> Enum.reject(fn {_key, val} -> is_nil(val) end)
    |> Enum.map_join("&", fn {key, val} -> "#{key}=#{val}" end)
  end

  defp to_property(property),
    do: %{
      id: property["name"],
      title: property["label"],
      hubspot_defined: property["hubspotDefined"] || false,
      fieldType: property["fieldType"],
      type: property["type"]
    }

  defp maybe_alter_object_name(object_name) when object_name in @plural_objects_types,
    do: object_name

  defp maybe_alter_object_name(object_name), do: "p_#{object_name}"

  defp maybe_add_standard_object_name(event) do
    case Map.get(event, "primaryObjectId") do
      nil ->
        event

      object_id ->
        case Map.get(@primary_standard_objects_ids, object_id) do
          nil ->
            event

          object_name ->
            event
            |> Map.put("objectName", String.capitalize(object_name))
            |> Map.put("isStandardObject", true)
        end
    end
  end

  defp maybe_add_custom_event_name(event, objects_ids_names_mapping) do
    case Map.get(objects_ids_names_mapping, event["primaryObjectId"]) do
      nil ->
        event

      mapped_object_name ->
        event
        |> Map.put("objectName", String.capitalize(mapped_object_name))
        |> Map.put("isStandardObject", false)
    end
  end

  defp maybe_build_custom_event_names_mapping(client_code, refresh_token, opts) do
    case Keyword.get(opts, :custom_event_names_mapping) do
      custom_event_names_mapping
      when is_map(custom_event_names_mapping) and map_size(custom_event_names_mapping) > 0 ->
        custom_event_names_mapping

      _ ->
        build_custom_event_names_mapping(client_code, refresh_token)
    end
  end

  defp build_custom_event_names_mapping(client_code, refresh_token) do
    case discovery_custom_objects(client_code, refresh_token) do
      {:ok, %{status: 200, body: %{"results" => custom_objects} = _body}} ->
        custom_objects
        |> Enum.reduce(%{}, fn object, acc ->
          Map.put(acc, object["objectTypeId"], object["labels"]["plural"])
        end)

      _error ->
        %{}
    end
  end
end
