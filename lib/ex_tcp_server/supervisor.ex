defmodule ExTCPServer.Supervisor do
  use Supervisor.Behaviour

  def start_link(name, mod, args, option) do
    :supervisor.start_link name, __MODULE__, {name, mod, args, option}
  end

  def stop(name) do
    case Process.whereis name do
      pid when is_pid pid ->
        Process.exit pid, :normal
        :ok
      _ ->
        {:error, :not_started}
    end
  end

  def init({name, mod, args, option}) do
    case mod.init args do
      {:ok, state} ->
        listen state, name, mod, option
      other ->
        :error_logger.warning_msg 'init(~p) ~p', [mod, other]
        :ignore
    end
  end

  def listen(state, name, mod, option) do
    case :gen_tcp.listen option.port, option.listen do
      {:ok, listen_socket} ->
        supervisor_spec listen_socket, state, name, mod, option
      other ->
        :error_logger.warning_msg 'listen(~p) ~p', [mod, other]
        :ignore
    end
  end

  def supervisor_spec(listen_socket, state, {dest, name}, mod, option) do
    monitor_name = build_monitor_name name
    {:ok, {
      {:one_for_one, option.max_restarts, option.time},
      [
        monitor_spec({dest, monitor_name}) |
        acceptor_specs(listen_socket, state, {dest, name}, monitor_name, mod, option)
      ]
    }}
  end

  def monitor_spec({dest, monitor_name}) do
    {
      monitor_name,
      {
        ExTCPServer.Monitor,
        :start_link,
        [{dest, monitor_name}]
      },
      :permanent,
      :brutal_kill,
      :worker,
      []
    }
  end

  def acceptor_specs(
    listen_socket, state, {dest, name}, monitor_base_name, mod, option
  ) do
    monitor_name = case dest do
      :local -> monitor_base_name 
      _Global -> {dest, monitor_base_name}
    end
    Enum.map 1..option.max_processes, fn(n) ->
      acceptor_name = build_acceptor_name name, n
      {
        acceptor_name,
        {
          ExTCPServer.Acceptor,
          :start_link,
          [
            {dest, acceptor_name},
            listen_socket,
            state,
            monitor_name,
            mod,
            option
          ]
        },
        :permanent,
        option.shutdown,
        :worker,
        []
      }
    end
  end

  def build_monitor_name(prefix) do
    atom_to_list(prefix) ++ '_monitor' |> list_to_atom
  end

  def build_acceptor_name(prefix, n) do
    atom_to_list(prefix) ++ '_acceptor_' ++ integer_to_list(n) |>
    list_to_atom
  end
end
