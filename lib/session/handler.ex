defmodule Gateway.Session do
  use GenServer

  defstruct session_id: nil,
            linked_socket: nil

  def start_link(state) do
    GenServer.start_link(__MODULE__, state, name: :"#{state.session_id}")
  end

  def init(state) do
    {:ok,
     %__MODULE__{
       session_id: state.session_id,
       linked_socket: nil
     }, {:continue, :setup_session}}
  end

  def handle_continue(:setup_session, state) do
    {:noreply, state}
  end

  def handle_info({:send_to_socket, message}, state) do
    send(state.linked_socket, {:remote_send, message})

    {:noreply, state}
  end

  def handle_info({:send_to_socket, message, socket}, state) when is_pid(socket) do
    send(socket, {:remote_send, message})

    {:noreply, state}
  end

  def handle_info({:send_init, socket}, state) when is_pid(socket) do
    send(socket, {:send_op, 0, %{heartbeat_interval: 25000}})

    {:ok, status_data} = Redix.command(:redix, ["HGETALL", "status/current"])

    status =
      status_data
      |> Gateway.Connectivity.RedisUtils.normalize()

    send(self(), {:send_status, status})

    {:ok, spotify_data} = Redix.command(:redix, ["GET", "spotify/current"])

    case Jason.decode(spotify_data) do
      {:ok, json} when is_map(json) ->
        send(self(), {:send_spotify, json})

        :ok

      _ ->
        :ok
    end

    {:noreply, state}
  end

  def handle_info({:send_spotify, data}, state) do
    send(state.linked_socket, {:send_op, 2, data})

    {:noreply, state}
  end

  def handle_info({:send_spotify_changed, data}, state) do
    send(state.linked_socket, {:send_op, 3, data})

    {:noreply, state}
  end

  def handle_info({:send_status, data}, state) do
    send(state.linked_socket, {:send_op, 4, data})

    {:noreply, state}
  end

  def handle_info({:send_puffco_temperature, data}, state) do
    send(state.linked_socket, {:send_op, 5, data})

    {:noreply, state}
  end

  def handle_cast({:link_socket, socket_pid}, state) do
    IO.puts("Linking socket to session #{state.session_id}")

    send(self(), {:send_init, socket_pid})

    {:noreply,
     %{
       state
       | linked_socket: socket_pid
     }}
  end
end
