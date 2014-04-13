defmodule ExTCPServerTest do
  use ExUnit.Case

  test "echo server" do
    # assert 1 + 1 == 2
    EchoServer.start_link
    {:ok, socket} = :gen_tcp.connect(
      {127,0,0,1}, 10000,
      [:binary, {:packet, :line}, {:active, false}]
    )

    :gen_tcp.send socket, "hello\r\n"

    case :gen_tcp.recv socket, 0 do
      data -> assert data == {:ok, "hello\r\n"}
    end

    :gen_tcp.send socket, "bye\r\n"

    case :gen_tcp.recv socket, 0 do
      data -> assert data == {:ok, "cya\r\n"}
    end

    :gen_tcp.close socket
    EchoServer.stop
  end
end

defmodule EchoServer do
  def start_link() do
    option = ExTCPServer.Option.new port: 10000, max_processes: 2
    ExTCPServer.start_link __MODULE__, [], option
  end

  def stop() do
    ExTCPServer.stop
  end

  def init(_args) do
    {:ok, {}}
  end

  def handle_call(_socket, "bye\r\n", state) do
    {:close, "cya\r\n", state}
  end

  def handle_call(_socket, "error\r\n", state) do
    (fn(n) -> 1 / n end).(0) # Always throws a bad arithmetic exception
    {:close, "error\r\n", state}
  end

  def handle_call(_socket, data, state) do
    {:reply, data, state}
  end
end
