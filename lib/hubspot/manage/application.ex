defmodule Hubspot.Manage.Application do
  @moduledoc """
  This module is used to manage all hubspot App API calls
  for example: listing current webhooks subscriptions,
  adding new subscriptions,...etc
  """

  alias Hubspot.Common.API

  use Hubspot.Common.Config
  require Logger

  @doc """
  list all the properties the hubspot app listens to changes for
  this includes default and custom properties
  """
  @spec list_app_properties() :: {:ok, map()} | {:error, map()}
  def list_app_properties() do
    with :ok <- validate_app_credentials(),
         {:ok, %{status: status, body: body}} <-
           API.request(
             :get,
             "/webhooks/v3/#{config(:app_id)}/subscriptions?hapikey=#{config(:api_key)}"
           ) do
      {:ok, %{status: status, body: filter_property_changes(body["results"])}}
    end
  end

  @doc """
  Add new hubspot properties subscriptions.
  If list properties is supplied, the function will list all the subscribed properies, then
  add subscriptions for all the properies that are not already subscribed.
  If a single property is subblied, it will directly add the property
  """
  @spec add_hubspot_property_subscription([map()] | map()) ::
          {:ok, String.t()} | {:error, String.t()}
  def add_hubspot_property_subscription(properties) when is_list(properties) do
    # Get all current app properties
    list_app_properties()
    |> case do
      {:ok,
       %{body: %{contact_properties: contact_properties, company_properties: company_properties}}} ->
        properties
        |> Enum.filter(
          &(&1["id"] not in contact_properties and &1["id"] not in company_properties)
        )
        |> Enum.map(&add_hubspot_property_subscription/1)
        |> Enum.all?(fn
          {:ok, %{status: 201}} ->
            true

          {status, body} ->
            Logger.warn(
              "error adding property subscription with response #{status} and body #{inspect(body)}"
            )

            false
        end)
        |> case do
          true -> {:ok, "property subscription added"}
          false -> {:error, "error adding property subscription"}
        end

      _ ->
        {:error, "error connecting to hubspot"}
    end
  end

  def add_hubspot_property_subscription(property) do
    Logger.debug("Adding property #{inspect(property)} to hubspot app subscriptions")

    API.request(
      :post,
      "/webhooks/v3/#{config(:app_id)}/subscriptions?hapikey=#{config(:api_key)}",
      Jason.encode!(%{
        active: true,
        eventType: "#{to_hubspot_object(property["type"])}.propertyChange",
        propertyName: property["id"]
      }),
      [
        {"content-type", "application/json"}
      ]
    )
  end

  defp to_hubspot_object(property_type) do
    case property_type do
      "company_property" -> "company"
      "user_property" -> "contact"
    end
  end

  # Make sure env variables provided
  defp validate_app_credentials() do
    if !config(:app_id) || !config(:api_key) do
      {:error, "Hubspot App credentials not provided(app_id and api_key)"}
    else
      :ok
    end
  end

  defp filter_property_changes(subscriptions) do
    %{
      contact_properties:
        subscriptions
        |> Enum.filter(&(&1["eventType"] == "contact.propertyChange"))
        |> Enum.map(& &1["propertyName"]),
      company_properties:
        subscriptions
        |> Enum.filter(&(&1["eventType"] == "company.propertyChange"))
        |> Enum.map(& &1["propertyName"])
    }
  end
end
