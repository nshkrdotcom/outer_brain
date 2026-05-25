defmodule OuterBrain.ContextABI.ContextPacket do
  @moduledoc """
  MVP Context ABI packet.
  """

  alias OuterBrain.ContextABI.{Canonical, Failure, Validator}

  @schema_ref "outer_brain.context_packet.mvp.v1"

  defstruct schema_ref: @schema_ref,
            context_packet_ref: nil,
            tenant_ref: nil,
            user_request_ref: nil,
            system_instruction_ref: nil,
            memory_refs: [],
            budget_ref: nil,
            model_class_allowlist: [],
            route_policy_ref: nil,
            trace_ref: nil,
            packet_hash: nil,
            extension_refs: %{}

  @type t :: %__MODULE__{
          schema_ref: String.t(),
          context_packet_ref: String.t(),
          tenant_ref: String.t(),
          user_request_ref: String.t(),
          system_instruction_ref: String.t(),
          memory_refs: [String.t()],
          budget_ref: String.t(),
          model_class_allowlist: [String.t()],
          route_policy_ref: String.t(),
          trace_ref: String.t(),
          packet_hash: String.t(),
          extension_refs: map()
        }

  @spec schema_ref() :: String.t()
  def schema_ref, do: @schema_ref

  @spec new(map() | keyword() | t()) :: {:ok, t()} | {:error, Failure.t()}
  def new(%__MODULE__{} = packet), do: packet |> Map.from_struct() |> new()
  def new(attrs) when is_list(attrs), do: attrs |> Map.new() |> new()

  def new(attrs) when is_map(attrs) do
    with :ok <- Validator.reject_raw_payload(attrs),
         {:ok, tenant_ref} <- Validator.required_string(attrs, :tenant_ref),
         {:ok, user_request_ref} <- Validator.required_string(attrs, :user_request_ref),
         {:ok, system_instruction_ref} <-
           Validator.required_string(attrs, :system_instruction_ref),
         {:ok, memory_refs} <- Validator.string_list(attrs, :memory_refs),
         :ok <- reject_unpromoted_memory_refs(memory_refs),
         {:ok, budget_ref} <- Validator.required_string(attrs, :budget_ref),
         {:ok, model_class_allowlist} <- Validator.string_list(attrs, :model_class_allowlist),
         :ok <- require_nonempty(model_class_allowlist, :model_class_allowlist),
         {:ok, route_policy_ref} <- Validator.required_string(attrs, :route_policy_ref),
         {:ok, trace_ref} <- Validator.required_string(attrs, :trace_ref),
         {:ok, extension_refs} <- Validator.optional_map(attrs, :extension_refs) do
      hash_input = %{
        schema_ref: Validator.fetch(attrs, :schema_ref, @schema_ref),
        tenant_ref: tenant_ref,
        user_request_ref: user_request_ref,
        system_instruction_ref: system_instruction_ref,
        memory_refs: memory_refs,
        budget_ref: budget_ref,
        model_class_allowlist: model_class_allowlist,
        route_policy_ref: route_policy_ref,
        trace_ref: trace_ref,
        extension_refs: extension_refs
      }

      packet_hash = Canonical.digest(hash_input)
      hash_suffix = String.replace_prefix(packet_hash, "sha256:", "")

      {:ok,
       %__MODULE__{
         schema_ref: hash_input.schema_ref,
         context_packet_ref: "context-packet://#{hash_suffix}",
         tenant_ref: tenant_ref,
         user_request_ref: user_request_ref,
         system_instruction_ref: system_instruction_ref,
         memory_refs: memory_refs,
         budget_ref: budget_ref,
         model_class_allowlist: model_class_allowlist,
         route_policy_ref: route_policy_ref,
         trace_ref: trace_ref,
         packet_hash: packet_hash,
         extension_refs: extension_refs
       }}
    end
  end

  def new(_attrs) do
    Validator.failure(:outer_brain, "outer_brain.context.invalid_packet.v1",
      safe_message: "context packet is invalid"
    )
  end

  @spec hash_input(t()) :: map()
  def hash_input(%__MODULE__{} = packet) do
    %{
      schema_ref: packet.schema_ref,
      tenant_ref: packet.tenant_ref,
      user_request_ref: packet.user_request_ref,
      system_instruction_ref: packet.system_instruction_ref,
      memory_refs: packet.memory_refs,
      budget_ref: packet.budget_ref,
      model_class_allowlist: packet.model_class_allowlist,
      route_policy_ref: packet.route_policy_ref,
      trace_ref: packet.trace_ref,
      extension_refs: packet.extension_refs
    }
  end

  @spec to_map(t()) :: map()
  def to_map(%__MODULE__{} = packet) do
    packet
    |> Map.from_struct()
    |> Canonical.normalize_for_boundary()
  end

  defp require_nonempty([], field) do
    Validator.failure(:outer_brain, "outer_brain.context.invalid_field.v1",
      safe_message: "context field is invalid",
      evidence_refs: ["field://#{Atom.to_string(field)}"]
    )
  end

  defp require_nonempty(_values, _field), do: :ok

  defp reject_unpromoted_memory_refs(memory_refs) do
    case Enum.find(memory_refs, &unpromoted_memory_ref?/1) do
      nil ->
        :ok

      ref ->
        Validator.failure(:outer_brain, "outer_brain.context.unpromoted_memory_candidate.v1",
          safe_message: "unpromoted memory candidates cannot enter production context packets",
          evidence_refs: [ref]
        )
    end
  end

  defp unpromoted_memory_ref?("memory-candidate://" <> _suffix), do: true
  defp unpromoted_memory_ref?(ref), do: String.contains?(ref, "/candidate/")
end
