defmodule ExTCPServer do
  def start_link(mod) do
    start_link mod, []
  end

  def start_link(mod, args) do
    start_link mod, args, ExTCPServer.Option.new()
  end

  def start_link(mod, args, option) do
    start_link {:local, __MODULE__}, mod, args, option
  end

  def start_link(name, mod, args, option) do
    ExTCPServer.Supervisor.start_link name, mod, args, option
  end

  def stop() do
    stop __MODULE__
  end

  def stop(name) do
    ExTCPServer.Supervisor.stop name
  end

  def info(key) do
    info __MODULE__, key
  end

  def info(name, key) do
    ExTCPServer.Supervisor.build_monitor_name name |>
    ExTCPServer.Monitor.info key
  end
end
