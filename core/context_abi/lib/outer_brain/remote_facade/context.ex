defmodule OuterBrain.RemoteFacade.Context do
  @moduledoc """
  OuterBrain-owned Context ABI facade for distributed StackLab profiles.

  Context compilation is a bounded synchronous seam. This facade exposes
  serializable packet and receipt maps; prompt rendering remains in
  `OuterBrain.Prompting.ContextRenderer`.
  """

  alias OuterBrain.ContextABI
  alias OuterBrain.ContextABI.{ContextPacket, ContextPacketReceipt, Failure}

  @owner_group {__MODULE__, :context}

  @spec owner_group() :: {module(), :context}
  def owner_group, do: @owner_group

  @spec compile_context(map(), keyword()) :: {:ok, map()} | {:error, map()}
  def compile_context(request, opts \\ []) when is_map(request) and is_list(opts) do
    case ContextABI.compile(request, opts) do
      {:ok, %ContextPacket{} = packet, %ContextPacketReceipt{} = receipt} ->
        {:ok,
         %{
           "context_packet" => ContextPacket.to_map(packet),
           "receipt" => receipt_map(receipt)
         }}

      {:error, %Failure{} = failure} ->
        {:error, failure_map(failure)}
    end
  end

  @spec readback_context(String.t(), keyword()) :: {:ok, map()} | {:error, map()}
  def readback_context(ref, opts \\ []) when is_binary(ref) and is_list(opts) do
    if String.trim(ref) == "" do
      {:error, error(:invalid_envelope, %{"missing_field" => "context_packet_ref"})}
    else
      {:ok,
       %{
         "context_packet_ref" => ref,
         "status" => Keyword.get(opts, :status, "available"),
         "owner" => "outer_brain",
         "payload_mode" => "refs_only"
       }}
    end
  end

  defp receipt_map(%ContextPacketReceipt{} = receipt) do
    %{
      "receipt_ref" => receipt.receipt_ref,
      "context_packet_ref" => receipt.context_packet_ref,
      "tenant_ref" => receipt.tenant_ref,
      "status" => Atom.to_string(receipt.status),
      "packet_hash" => receipt.packet_hash,
      "included_refs" => receipt.included_refs,
      "blocked_refs" => receipt.blocked_refs,
      "trace_ref" => receipt.trace_ref
    }
  end

  defp failure_map(%Failure{} = failure) do
    %{
      "code" => "context_compile_failed",
      "owner" => Atom.to_string(failure.owner),
      "reason_code" => failure.reason_code,
      "safe_message" => failure.safe_message,
      "retryable" => failure.retryable?,
      "trace_ref" => failure.trace_ref,
      "evidence_refs" => failure.evidence_refs
    }
  end

  defp error(code, attrs) do
    Map.merge(
      %{
        "code" => Atom.to_string(code),
        "owner" => "outer_brain",
        "facade" => "context"
      },
      attrs
    )
  end
end
