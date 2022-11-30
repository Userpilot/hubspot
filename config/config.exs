import Config

config :hubspot, Hubspot.Common.API, http_api: "https://api.hubapi.com"

import_config "#{Mix.env()}.exs"
