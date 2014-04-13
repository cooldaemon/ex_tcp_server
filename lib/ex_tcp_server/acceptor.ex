defmodule ExTCPServer.Acceptor do
  def start_link(
    {dest, name}, listen_socket, state, monitor_name, mod, option
  ) do
    {:ok, pid} = :proc_lib.start_link(
      __MODULE__, :init,
      [self(), listen_socket, state, monitor_name, mod, option]
    )
    case dest do
      :local -> Process.register pid, name
      _Global -> :global.register_name name, pid
    end
    {:ok, pid}
  end

  def init(parent, listen_socket, state, monitor_name, mod, option) do
    :proc_lib.init_ack parent, {:ok, self()}
    ExTCPServer.Monitor.register monitor_name, self()
    accept listen_socket, state, monitor_name, mod, option
  end

  def accept(listen_socket, state, monitor_name, mod, option) do
    case :gen_tcp.accept listen_socket, option.accept_timeout do
      {:ok, socket} ->
        try do
          ExTCPServer.Monitor.increment monitor_name, self()
          recv option.listen[:active], socket, state, mod, option
        rescue
          error ->
            :error_logger.warning_msg 'accept(~p) ~p', [mod, error]
        after
          ExTCPServer.Monitor.decrement monitor_name, self()
          :gen_tcp.close socket
        end
      other ->
        :error_logger.warning_msg 'accept(~p) ~p', [mod, other]
        :timer.sleep option.accept_error_sleep_time
    end
    accept listen_socket, state, monitor_name, mod, option
  end

  def recv(false, socket, state, mod, option) do
    case :gen_tcp.recv socket, option.recv_length, option.recv_timeout do
      {:ok, data} ->
        call_mod false, socket, data, state, mod, option
      {:error, :closed} ->
        :ok
      other ->
        :error_logger.warning_msg 'recv(~p) ~p', [mod, other]
        :ok
    end
  end

  def recv(true, _dummy_socket, state, mod, option) do
    receive do
      {:tcp, socket, data} ->
        call_mod true, socket, data, state, mod, option
      {:tcp_closed, _socket} ->
        :ok
      other ->
        :error_logger.warning_msg 'recv(~p) ~p', [mod, other]
        :ok
    after
      option.recv_timeout ->
        :error_logger.warning_msg "recv(~p) ~p", [mod, {:error, :timeout}]
        :ok
    end
  end

  def call_mod(active, socket, data, state, mod, option) do
    case mod.handle_call socket, data, state do
      {:reply, data_to_send, state} ->
        send socket, data_to_send, mod
        recv active, socket, state, mod, option
      {:noreply, state} ->
        recv active, socket, state, mod, option
      {:close, _state} ->
        :ok
      {:close, data_to_send, _state} ->
        send socket, data_to_send, mod
      other ->
        :error_logger.warning_msg 'call_mod(~p) ~p', [mod, {:unexpected_result, other}]
        :ok
    end
  end

  def send(socket, data, mod) do
    case :gen_tcp.send(socket, data) do
      :ok -> 
        :ok
      other ->
        :error_logger.warning_msg 'send(~p) ~p', [mod, other]
        :ok
    end
  end
end
