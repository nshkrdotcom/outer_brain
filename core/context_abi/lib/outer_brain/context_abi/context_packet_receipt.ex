defmodule OuterBrain.ContextABI.ContextPacketReceipt do
  @moduledoc """
  Evidence that a Context ABI packet was compiled or rejected.
  """

  alias OuterBrain.ContextABI.{ContextPacket, Failure}

  @type status :: :compiled | :rejected

  defstruct [
    :receipt_ref,
    :context_packet_ref,
    :tenant_ref,
    :status,
    :packet_hash,
    :failure,
    included_refs: [],
    blocked_refs: [],
    trace_ref: nil
  ]

  @type t :: %__MODULE__{
          receipt_ref: String.t(),
          context_packet_ref: String.t(),
          tenant_ref: String.t(),
          status: status(),
          packet_hash: String.t() | nil,
          failure: Failure.t() | nil,
          included_refs: [String.t()],
          blocked_refs: [String.t()],
          trace_ref: String.t()
        }

  @spec compiled(ContextPacket.t()) :: t()
  def compiled(%ContextPacket{} = packet) do
    %__MODULE__{
      receipt_ref:
        packet.packet_hash |> String.replace_prefix("sha256:", "context-packet-receipt://"),
      context_packet_ref: packet.context_packet_ref,
      tenant_ref: packet.tenant_ref,
      status: :compiled,
      packet_hash: packet.packet_hash,
      included_refs:
        [packet.user_request_ref, packet.system_instruction_ref | packet.memory_refs]
        |> Enum.reject(&is_nil/1),
      blocked_refs: [],
      trace_ref: packet.trace_ref
    }
  end

  @spec rejected(Failure.t(), map()) :: t()
  def rejected(%Failure{} = failure, attrs \\ %{}) when is_map(attrs) do
    %__MODULE__{
      receipt_ref:
        Map.get(attrs, :receipt_ref) || Map.get(attrs, "receipt_ref") ||
          "context-packet-receipt://rejected",
      context_packet_ref:
        Map.get(attrs, :context_packet_ref) || Map.get(attrs, "context_packet_ref"),
      tenant_ref: Map.get(attrs, :tenant_ref) || Map.get(attrs, "tenant_ref"),
      status: :rejected,
      packet_hash: nil,
      failure: failure,
      included_refs: [],
      blocked_refs: Map.get(attrs, :blocked_refs) || Map.get(attrs, "blocked_refs") || [],
      trace_ref: failure.trace_ref || Map.get(attrs, :trace_ref) || Map.get(attrs, "trace_ref")
    }
  end
end
