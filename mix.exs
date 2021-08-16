defmodule Gateway.MixProject do
  use Mix.Project

  def project do
    [
      app: :gateway,
      version: "0.1.0",
      elixir: "~> 1.12",
      start_permanent: Mix.env() == :prod,
      deps: deps()
    ]
  end

  def application do
    [
      extra_applications: [:logger],
      mod: {Gateway, []}
    ]
  end

  defp deps do
    [
      {:gen_registry, "~> 1.1.0"},
      {:plug_cowboy, "~> 2.0"},
      {:prometheus_plugs, "~> 1.1"},
      {:prometheus_ex, "~> 3.0"},
      {:redix, "~> 1.1"},
      {:uuid, "~> 1.1"},
      {:jason, "~> 1.2"},
      {:amqp, "~> 2.1"}
    ]
  end
end
