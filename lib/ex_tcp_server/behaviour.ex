defmodule ExTCPServer.Behaviour do
  use Behaviour

  @doc false
  defcallback init(args :: list) :: tuple

  @doc false
  defcallback handle_call(socket :: any, data :: binary, state :: any) :: tuple
end
