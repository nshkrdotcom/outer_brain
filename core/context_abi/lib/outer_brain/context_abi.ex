defmodule OuterBrain.ContextABI do
  @moduledoc """
  Public facade for the OuterBrain Context ABI MVP.
  """

  alias OuterBrain.ContextABI.{Compiler, ContextPacket, ContextPacketReceipt, Failure}

  @spec compile(Compiler.compile_request(), keyword()) ::
          {:ok, ContextPacket.t(), ContextPacketReceipt.t()} | {:error, Failure.t()}
  def compile(request, opts \\ []) do
    compiler = Keyword.get(opts, :compiler, Compiler)
    compiler.compile(request, Keyword.delete(opts, :compiler))
  end
end
