defmodule Hubspot.Application do
  use Application

  @impl true
  def start(_type, _args) do
    children = [
      {Cachex, name: :hubspot_cache},
      {Finch, name: Hubspot.Common.API}
    ]

    # See https://hexdocs.pm/elixir/Supervisor.html
    # for other strategies and supported options
    opts = [strategy: :one_for_one, name: Hubspot.Supervisor]
    Supervisor.start_link(children, opts)
  end
end
