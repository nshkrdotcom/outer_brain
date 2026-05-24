defmodule OuterBrain.ContextABI.Compiler do
  @moduledoc """
  Behaviour and deterministic MVP compiler for Context ABI packets.
  """

  alias OuterBrain.ContextABI.{ContextPacket, ContextPacketReceipt, Failure}

  @type compile_request :: %{
          required(:tenant_ref) => String.t(),
          required(:user_request_ref) => String.t(),
          required(:system_instruction_ref) => String.t(),
          optional(:memory_refs) => [String.t()],
          required(:budget_ref) => String.t(),
          required(:model_class_allowlist) => [String.t()],
          required(:route_policy_ref) => String.t(),
          required(:trace_ref) => String.t()
        }

  @callback compile(compile_request(), keyword()) ::
              {:ok, ContextPacket.t(), ContextPacketReceipt.t()} | {:error, Failure.t()}

  @spec compile(compile_request(), keyword()) ::
          {:ok, ContextPacket.t(), ContextPacketReceipt.t()} | {:error, Failure.t()}
  def compile(request, opts \\ [])

  def compile(request, opts) when is_map(request) and is_list(opts) do
    request
    |> ContextPacket.new()
    |> case do
      {:ok, packet} -> {:ok, packet, ContextPacketReceipt.compiled(packet)}
      {:error, %Failure{} = failure} -> {:error, failure}
    end
  end

  def compile(_request, _opts) do
    {:ok, failure} =
      Failure.new(%{
        owner: :outer_brain,
        reason_code: "outer_brain.context.invalid_compile_request.v1",
        safe_message: "context compile request is invalid"
      })

    {:error, failure}
  end
end
