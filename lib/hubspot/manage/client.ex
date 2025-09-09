defmodule Hubspot.Manage.Client do
  @moduledoc """
  This module is used to manage all hubspot Clients API calls
  for example: Contact/Company properties, contacts/companies syncing
  """

  alias Hubspot.Common.API
  alias Hubspot.Auth.Manage.Token

  @custom_events_write_scope "behavioral_events.event_definitions.read_write"

  @primary_standard_objects_ids %{
    "0-1" => "contact",
    "0-2" => "company",
    "0-3" => "deal",
    "0-5" => "ticket",
    "0-162" => "service",
    "0-53" => "invoice",
    "0-7" => "product",
    "0-14" => "quote",
    "0-69" => "subscription",
    "0-123" => "order",
    "0-142" => "cart"
  }

  @primary_standard_objects_ids_map @primary_standard_objects_ids
                                    |> Enum.map(fn {k, v} -> {v, k} end)
                                    |> Enum.into(%{})

  # This needs to build an API function working with standard object and custom object ones
  @standard_objects_types @primary_standard_objects_ids
                          |> Enum.map(fn {_k, v} -> String.to_existing_atom(v) end)
                          |> Enum.into([])

  @eventable_standard_objects_types [
    "contacts",
    "companies",
    "deals",
    "tickets"
  ]

  @plural_standard_objects_types [
    "contacts",
    "companies",
    "deals",
    "tickets",
    "services",
    "invoices",
    "products",
    "quotes",
    "subscriptions",
    "orders",
    "carts"
  ]

  @standard_objects_types_map %{
    contact: "contacts",
    company: "companies",
    deal: "deals",
    ticket: "tickets",
    service: "services",
    invoice: "invoices",
    product: "products",
    quote: "quotes",
    subscription: "subscriptions",
    order: "orders",
    cart: "carts"
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

  @spec allowed_to_use_custom_events?(String.t(), String.t()) ::
          {:ok, boolean()} | {:error, map()}
  def allowed_to_use_custom_events?(client_code, refresh_token) do
    client_code
    |> Token.get_client_scopes(refresh_token)
    |> case do
      {:ok, scope} ->
        if @custom_events_write_scope in scope do
          {:ok, true}
        else
          {:ok, false}
        end

      {:not_found, reason} ->
        {:error, reason}
    end
  end

  @spec get_custom_event(String.t(), String.t(), String.t()) :: {:ok, map()} | {:error, map()}
  def get_custom_event(client_code, refresh_token, custom_event_name) do
    client_code
    |> Token.get_client_access_token(refresh_token)
    |> case do
      {:ok, token} ->
        API.request(:get, "/events/v3/event-definitions/#{custom_event_name}", nil, [
          {"authorization", "Bearer #{token}"},
          {"accept", "application/json"}
        ])

      {:error, reason} ->
        {:error, reason}
    end
  end

  @spec send_custom_event(
          String.t(),
          String.t(),
          :object_id | :email,
          String.t(),
          map(),
          String.t()
        ) ::
          {:ok, map()} | {:error, map()}
  def send_custom_event(
        client_code,
        refresh_token,
        :object_id,
        custom_event_name,
        params,
        object_id
      ) do
    client_code
    |> Token.get_client_access_token(refresh_token)
    |> case do
      {:ok, token} ->
        API.request(
          :post,
          "/events/v3/send",
          Jason.encode!(%{
            eventName: custom_event_name,
            objectId: object_id,
            occurredAt: Map.get(params, "occurred_at", DateTime.now!("Etc/UTC")),
            properties: %{
              event_type: Map.get(params, "event_type", ""),
              event_id: Map.get(params, "event_id", ""),
              event_name: Map.get(params, "event_name", ""),
              event_title: Map.get(params, "event_title", ""),
              event_platform: Map.get(params, "event_platform", ""),
              hostname: Map.get(params, "hostname", ""),
              pathname: Map.get(params, "pathname", "")
            }
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

  @spec define_custom_event(String.t(), String.t(), map()) :: {:ok, map()} | {:error, map()}
  def define_custom_event(client_code, refresh_token, event_body) do
    client_code
    |> Token.get_client_access_token(refresh_token)
    |> case do
      {:ok, token} ->
        API.request(
          :post,
          "/events/v3/event-definitions",
          Jason.encode!(%{
            label: event_body[:label],
            name: event_body[:name],
            description: event_body[:description],
            primaryObject: event_body[:primary_object],
            includeDefaultProperties: event_body[:include_default_properties] || true,
            propertyDefinitions: event_body[:property_definitions]
          }),
          [
            {"Content-type", "application/json"},
            {"authorization", "Bearer #{token}"},
            {"accept", "application/json"}
          ]
        )

      {:error, reason} ->
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
         body: Enum.map(body["results"], &to_object(&1, :custom_object)) ++ get_standard_objects()
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

  defp get_standard_objects(),
    do: Enum.map(@standard_objects_types, &to_object(&1, :standard_object))

  defp to_object(object, :custom_object) do
    %{
      fully_qualified_name: object["fullyQualifiedName"],
      singular_name: object["labels"]["singular"],
      plural_name: object["labels"]["plural"],
      primary_object_id: object["objectTypeId"],
      is_standard_object: false,
      is_custom_object: true,
      requires_custom_events: true,
      eventable: eventable?(object["labels"]["plural"], :custom_object)
    }
  end

  defp to_object(object_name, :standard_object) do
    %{
      fully_qualified_name: @standard_objects_types_map[object_name],
      singular_name: to_string(object_name),
      plural_name: @standard_objects_types_map[object_name],
      primary_object_id: @primary_standard_objects_ids_map[to_string(object_name)],
      is_standard_object: true,
      is_custom_object: false,
      requires_custom_events:
        not Enum.member?(
          @eventable_standard_objects_types,
          @standard_objects_types_map[object_name]
        ),
      eventable: eventable?(@standard_objects_types_map[object_name], :standard_object)
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
      is_custom_property: property["hubspotDefined"] || false,
      type: property["type"]
    }

  defp maybe_alter_object_name(object_name) when object_name in @plural_standard_objects_types,
    do: object_name

  defp maybe_alter_object_name(object_name), do: "p_#{object_name}"

  defp eventable?(_object_name, :custom_object), do: true

  defp eventable?(object_name, :standard_object)
       when object_name in @eventable_standard_objects_types,
       do: true

  defp eventable?(_object_name, :standard_object), do: false
end
