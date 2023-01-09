defmodule Gateway.Connectivity.Rabbit do
  use GenServer
  use AMQP

  def start_link(state) do
    GenServer.start_link(__MODULE__, state, name: :rabbit)
  end

  def init(_state) do
    {:ok, conn} = AMQP.Connection.open("#{Application.fetch_env!(:gateway, :rabbit_uri)}")
    {:ok, chan} = AMQP.Channel.open(conn)

    AMQP.Queue.declare(chan, "dstn-gateway-ingest", durable: true)
    {:ok, _tag} = Basic.consume(chan, "dstn-gateway-ingest")

    {:ok, chan}
  end

  def handle_info({:basic_consume_ok, %{consumer_tag: _tag}}, chan) do
    {:noreply, chan}
  end

  def handle_info({:basic_cancel, %{consumer_tag: _tag}}, chan) do
    {:stop, :normal, chan}
  end

  def handle_info({:basic_cancel_ok, %{consumer_tag: _tag}}, chan) do
    {:noreply, chan}
  end

  def handle_info({:basic_deliver, payload, %{delivery_tag: tag, routing_key: routing_key}}, chan) do
    Task.start(fn ->
      consume(chan, tag, routing_key, payload)
    end)

    {:noreply, chan}
  end

  defp consume(channel, tag, queue_name, payload) do
    :ok = Basic.ack(channel, tag)

    case Jason.decode(payload) do
      {:ok, json} when is_map(json) ->
        action(json, queue_name)

      _ ->
        payload
        |> :erlang.binary_to_term()
        |> action(queue_name)
    end
  rescue
    exception ->
      :ok = Basic.ack(channel, tag)
      IO.inspect(exception)
      IO.puts("Error converting payload to term")
  end

  defp action(data, queue_name) do
    case queue_name do
      "dstn-gateway-ingest" ->
        case data["t"] do
          0 ->
            {_max_id, _max_pid} =
              GenRegistry.reduce(Gateway.Session, {nil, -1}, fn
                {_id, pid}, {_, _current} = _acc ->
                  send(pid, {:send_spotify_changed, data["d"]})
              end)

          0 ->
            {_max_id, _max_pid} =
              GenRegistry.reduce(Gateway.Session, {nil, -1}, fn
                {_id, pid}, {_, _current} = _acc ->
                  send(pid, {:send_puffco_temperature, data["d"]})
              end)
        end

      _ ->
        nil
    end
  end
end
