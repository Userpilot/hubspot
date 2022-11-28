defmodule Hubspot.Common.Helpers do
  def normalize_api_response({status, %{body: body}}), do: {status, body}
end
