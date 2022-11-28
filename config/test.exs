import Config

rabbitmq_configs = [
  host: "127.0.0.1",
  port: 5672,
  username: "guest",
  password: "guest"
]

config :accounts, Accounts.Repo,
  database: "userpilot-dev",
  username: "admin",
  password: "c;_VAC4N?tA#X9ecWP>",
  hostname: "dev-cluster.cluster-cx5pzxfzqnfa.us-west-2.rds.amazonaws.com"

config :envoy, Envoy.Clickhouse.Repo,
  scheme: :http,
  loggers: [Ecto.LogEntry],
  hostname: "127.0.0.1",
  port: 8123,
  database: "analytex_db",
  username: "default",
  password: ""

config :core, Core.Clickhouse.Repo,
  scheme: :http,
  loggers: [Ecto.LogEntry],
  hostname: "127.0.0.1",
  port: 8123,
  database: "analytex_db",
  username: "default",
  password: ""

config :core, Core.Clickhouse.WriteEvents,
  max_buffer_size: 1,
  flush_interval_ms: 5000,
  pool_size: 1

config :http, HttpWeb.Plugs.Segment, shared_secret: "SHARED_SECRET"

config :http, HttpWeb.Endpoint,
  http: [port: 4002],
  server: false

config :websocket, WebsocketWeb.Endpoint,
  http: [port: 4003],
  server: false

config :http, HttpWeb.Plugs.Attack,
  ip_rate_limit: 10,
  app_rate_limit: 10,
  rate_limit_period: 60_000

config :websocket, Websocket.Plugs.Attack, rate_limit: 10, rate_limit_period: 60_000

config :bridge, Bridge.Scheduler, jobs: []

config :core, Core.Notifications.Mailer, adapter: Bamboo.TestAdapter

config :geolix,
  databases: [
    %{
      id: :country,
      adapter: Geolix.Adapter.Fake,
      data: %{
        {1, 1, 1, 1} => %{country: %{iso_code: "US"}},
        {2, 2, 2, 2} => %{country: %{iso_code: "GB"}}
      }
    }
  ]

config :core, Core.Webhooks.Publisher,
  flush_interval_ms: 10_000,
  max_buffer_size: 500,
  pool_size: 2,
  connection: rabbitmq_configs

config :envoy, Envoy.Consumer,
  connection: rabbitmq_configs,
  producer: [
    backoff_min: 1000,
    backoff_max: 180_000,
    backoff_type: :exp,
    prefetch_count: 200,
    concurrency: 1
  ],
  processors: [
    concurrency: "CONSUMER_PROCESSOR_CONCURRENCY" |> System.get_env("3") |> String.to_integer()
  ],
  batchers: [
    batch_size: 20,
    batch_timeout: 1_500,
    concurrency: "CONSUMER_BATCHER_CONCURRENCY" |> System.get_env("5") |> String.to_integer()
  ]

config :envoy, Envoy.Logger.Consumer,
  connection: rabbitmq_configs,
  clickhouse: [
    rate_limit_period: 60_000,
    rate_limit: 1
  ],
  producer: [
    backoff_min: 1_000,
    backoff_max: 180_000,
    backoff_type: :exp,
    prefetch_count: 2000,
    concurrency: 1
  ],
  processors: [
    concurrency: 1
  ],
  batchers: [
    batch_size: 2000,
    batch_timeout: 60_000,
    concurrency: 1
  ]

config :envoy, Envoy.QueueWarmer, connection: rabbitmq_configs

config :envoy, Envoy.Publisher,
  flush_interval_ms: 10_000,
  max_buffer_size: 500,
  pool_size: 2,
  max_retries: 5,
  retry_delay_ms: 10_000,
  connection: rabbitmq_configs
