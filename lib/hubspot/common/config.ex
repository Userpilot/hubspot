defmodule Hubspot.Common.Config do
  @spec __using__(any) :: {:__block__, [], [{:def, [...], [...]}, ...]}
  defmacro __using__(_options \\ nil) do
    quote do
      def config, do: Application.get_env(:hubspot, Hubspot.Common.API)
      def config(key), do: Application.get_env(:hubspot, Hubspot.Common.API)[key]
    end
  end
end
