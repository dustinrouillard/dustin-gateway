defmodule Gateway.Socket.Handler do
  @behaviour :cowboy_websocket

  @type t :: %{
          session_id: nil,
          linked_session: pid,
          encoding: nil,
          compression: nil
        }

  defstruct session_id: nil,
            linked_session: nil,
            encoding: nil,
            compression: nil

  def init(request, _state) do
    compression =
      request
      |> :cowboy_req.parse_qs()
      |> Enum.find(fn {name, _value} -> name == "compression" end)
      |> case do
        {_name, "zlib"} -> :zlib
        _ -> :none
      end

    encoding =
      request
      |> :cowboy_req.parse_qs()
      |> Enum.find(fn {name, _value} -> name == "encoding" end)
      |> case do
        {_name, "etf"} -> :etf
        _ -> :json
      end

    session_id = UUID.uuid4()

    {:ok, session} =
      GenRegistry.lookup_or_start(Gateway.Session, session_id, [%{session_id: session_id}])

    Gateway.Metrics.Collector.inc(:gauge, :dstn_gateway_connected_sessions)

    state = %__MODULE__{
      linked_session: session,
      session_id: session_id,
      compression: compression,
      encoding: encoding
    }

    {:cowboy_websocket, request, state}
  end

  def websocket_init(state) do
    GenServer.cast(state.linked_session, {:link_socket, self()})

    {:ok, state}
  end

  def websocket_handle({:binary, message}, state) do
    {:ok, data} = inflate_msg(message)
    message = Jason.decode!(data)
    handle_message(message, state)

    {:ok, state}
  end

  def websocket_handle({:text, message}, state) do
    case Jason.decode(message) do
      {:ok, json} when is_map(json) ->
        handle_message(json, state)
        {:ok, state}

      _ ->
        {:ok, state}
    end
  end

  def websocket_info({:send_op, op, data}, state) do
    send(
      self(),
      {:remote_send, construct_msg(state.encoding, state.compression, %{op: op, d: data})}
    )

    {:ok, state}
  end

  def websocket_info({:send_op, op}, state) do
    send(self(), {:remote_send, construct_msg(state.encoding, state.compression, %{op: op})})

    {:ok, state}
  end

  def websocket_info({:remote_send, data}, state) do
    Gateway.Metrics.Collector.inc(:counter, :dstn_gateway_messages_outbound)
    {:reply, data, state}
  end

  def websocket_info({:send_to_linked_session, message}, state) do
    send(state.linked_session, message)
    {:ok, state}
  end

  def websocket_info(info, state) do
    {:reply, {:text, info}, state}
  end

  def websocket_info(message, req, state) do
    {:reply, {:text, message}, req, state}
  end

  def terminate(_reason, _req, state) do
    IO.puts("Lost socket connection #{state.session_id}")
    GenRegistry.stop(Gateway.Session, state.session_id)
    Gateway.Metrics.Collector.dec(:gauge, :dstn_gateway_connected_sessions)
    :ok
  end

  defp handle_message(data, state) do
    Gateway.Metrics.Collector.inc(:counter, :dstn_gateway_messages_inbound)

    case data["op"] do
      6 ->
        GenServer.cast(state.linked_session, {:listen, data["d"]["channel"]})

      _ ->
        nil
    end
  end

  defp inflate_msg(data) do
    z = :zlib.open()
    :zlib.inflateInit(z)

    data = :zlib.inflate(z, data)

    :zlib.inflateEnd(z)

    {:ok, data}
  end

  defp construct_msg(encoding, compression, data) do
    data =
      case encoding do
        :etf ->
          data

        _ ->
          data |> Jason.encode!()
      end

    case compression do
      :zlib ->
        z = :zlib.open()
        :zlib.deflateInit(z)

        data = :zlib.deflate(z, data, :finish)

        :zlib.deflateEnd(z)

        {:binary, data}

      _ ->
        {:text, data}
    end
  end
end
