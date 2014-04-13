defmodule ExTCPServer.Monitor do
  use GenServer.Behaviour

  def start_link(name) do
    :gen_server.start_link name, __MODULE__, [], []
  end

  def stop(server_ref) do
    :gen_server.call server_ref, :stop
  end

  def register(server_ref, pid) do
    :gen_server.call server_ref, {:register, pid}
  end

  def increment(server_ref, pid) do
    :gen_server.cast server_ref, {:increment, pid}
  end

  def decrement(server_ref, pid) do
    :gen_server.cast server_ref, {:decrement, pid}
  end

  def info(server_ref, key) do
    :gen_server.call server_ref, {:info, key}
  end

  def init(_args) do
    {:ok, {_monitor_refs = [], _pids = []}}
  end

  def handle_call(:stop, _from, state) do
    {:stop, :normal, :stopped, state}
  end

  def handle_call({:register, pid}, _from, {monitor_refs, pids}) do
    {:reply, :ok, {
      [Process.monitor(pid) | monitor_refs],
      pids
    }}
  end

  def handle_call({:info, key}, _from, state) do
    {:reply, state_to_info(state, key), state}
  end

  def handle_call(_message, _from, state) do
    {:reply, :ok, state}
  end

  def handle_cast({:increment, pid}, {monitor_refs, pids}) do
    {:noreply, {monitor_refs, [pid | pids]}}
  end

  def handle_cast({:decrement, pid}, {monitor_refs, pids}) do
    {:noreply, {monitor_refs, Lists.delete(pids, pid)}}
  end

  def handle_cast(_message, state) do
    {:noreply, state}
  end

  def handle_info(
    {DOWN, monitor_ref, _type, pid, _info}, {monitor_refs, pids}
  ) do
    Process.demonitor(monitor_ref)
    {:noreply, {
      List.delete(monitor_refs, monitor_ref),
      List.delete(pids, pid)
    }}
  end

  def handle_info(_info, state) do
    {:noreply, state}
  end

  def terminate(_reason, _state) do
    :ok
  end

  def code_change(_old_vsn, state, _extra) do
    {:ok, state}
  end

  def state_to_info({_monitor_refs, pids}, :curr_connections) do
    length(pids)
  end

  def state_to_info(_state, _key) do
    :undefined
  end
end
