defmodule Hubspot.Manage.Application do
  @moduledoc """
  This module is used to manage all hubspot App API calls
  for example: listing current webhooks subscriptions,
  adding new subscriptions,...etc
  """

  alias Hubspot.Common.API
  alias Hubspot.Common.Helpers

  use Hubspot.Common.Config
  require Logger

  @doc """
  list all the properties the hubspot app listens to changes for
  this includes default and custom properties
  """
  @spec list_app_properties() :: {:ok, list()} | {:error, map()}
  def list_app_properties() do
    validate_app_credentials()

    API.request(
      :get,
      "/webhooks/v3/#{config(:app_id)}/subscriptions?hapikey=#{config(:api_key)}"
    )
    |> Helpers.normalize_api_response()
    |> case do
      {:ok, body} -> {:ok, filter_property_changes(body["results"])}
      {:error, body} -> {:error, body}
    end
  end

  @doc """
  Add new hubspot properties subscriptions.
  If list properties is supplied, the function will list all the subscribed properies, then
  add subscriptions for all the properies that are not already subscribed.
  If a single property is subblied, it will directly add the property
  """
  @spec add_hubspot_property_subscription([String.t()]) ::
          {:ok, String.t()} | {:error, String.t()}
  def add_hubspot_property_subscription(property_names) when is_list(property_names) do
    # Get all current app properties
    {:ok, app_properties} = list_app_properties()

    property_names
    |> Enum.filter(&(&1 not in app_properties))
    |> Enum.map(&add_hubspot_property_subscription/1)
  end

  @spec add_hubspot_property_subscription(String.t()) :: list()
  def add_hubspot_property_subscription(property_name) when is_binary(property_name) do
    Logger.debug("Adding property #{property_name} to hubspot app subscriptions")

    API.request(
      :post,
      "/webhooks/v3/#{config(:app_id)}/subscriptions?hapikey=#{config(:api_key)}",
      Jason.encode!(%{
        active: true,
        eventType: "contact.propertyChange",
        propertyName: property_name
      }),
      [
        {"content-type", "application/json"}
      ]
    )
    |> Helpers.normalize_api_response()
  end

  # Make sure env variables provided
  defp validate_app_credentials() do
    if !config(:app_id) || !config(:api_key),
      do: {:error, "Hubspot App credentials not provided(app_id and api_key)"}
  end

  defp filter_property_changes(subscriptions) do
    Enum.filter(subscriptions, fn subscription ->
      subscription["eventType"] == "contact.propertyChange"
    end)
    |> Enum.map(& &1["propertyName"])
  end
end