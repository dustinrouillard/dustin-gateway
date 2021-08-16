defmodule Gateway.Metrics.Collector do
  use Prometheus.Metric

  @registry :dstn_gateway_registry

  def start do
    Gauge.new(
      name: :dstn_gateway_connected_sessions,
      registry: @registry,
      labels: [],
      help: "Number of currently connected sessions."
    )

    Counter.new(
      name: :dstn_gateway_messages_outbound,
      registry: @registry,
      labels: [],
      help: "Number of total messages sent since pod creation."
    )

    Counter.new(
      name: :dstn_gateway_messages_inbound,
      registry: @registry,
      labels: [],
      help: "Number of total messages received since pod creation."
    )
  end

  def dec(:gauge, stat) do
    Gauge.dec(name: stat, registry: @registry)
  end

  def inc(:gauge, stat) do
    Gauge.inc(name: stat, registry: @registry)
  end

  def inc(:counter, stat) do
    Counter.inc(name: stat, registry: @registry)
  end

  def set(:gauge, stat, value) do
    Gauge.set([name: stat, registry: @registry], value)
  end
end
