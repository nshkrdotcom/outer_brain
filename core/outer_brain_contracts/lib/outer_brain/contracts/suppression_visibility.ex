defmodule OuterBrain.Contracts.SuppressionVisibility do
  @moduledoc """
  Phase 4 operator-visible suppression and quarantine contract.

  Suppression or quarantine can hide work from normal publication paths only
  when the operator can see the reason, target, trace, diagnostics, and recovery
  posture.
  """

  alias OuterBrain.Contracts.Phase4SemanticContract

  @contract_name "Platform.SuppressionVisibility.v1"
  @visibility ["visible"]
  @fields Phase4SemanticContract.scope_fields() ++
            [
              :principal_ref,
              :system_actor_ref,
              :suppression_ref,
              :suppression_kind,
              :reason_code,
              :target_ref,
              :operator_visibility,
              :recovery_action_refs,
              :diagnostics_ref
            ]

  @required_strings [
    :suppression_ref,
    :suppression_kind,
    :reason_code,
    :target_ref,
    :diagnostics_ref
  ]

  defstruct [:contract_name | @fields]

  @type t :: %__MODULE__{}

  @spec new(map() | t()) :: {:ok, t()} | {:error, term()}
  def new(%__MODULE__{} = contract), do: contract |> to_map() |> new()

  def new(attrs) when is_map(attrs) do
    with :ok <- Phase4SemanticContract.required_scope(attrs),
         :ok <- Phase4SemanticContract.required_strings(attrs, @required_strings),
         :ok <- Phase4SemanticContract.string_enum(attrs, :operator_visibility, @visibility),
         {:ok, recovery_action_refs} <-
           Phase4SemanticContract.required_non_empty_list(attrs, :recovery_action_refs) do
      {:ok, build(attrs, recovery_action_refs)}
    end
  end

  def new(_attrs), do: {:error, :invalid_suppression_visibility}

  @spec to_map(t()) :: map()
  def to_map(%__MODULE__{} = contract),
    do: Map.from_struct(contract) |> Map.delete(:contract_name)

  defp build(attrs, recovery_action_refs) do
    struct!(
      __MODULE__,
      Map.new(@fields, &{&1, Phase4SemanticContract.fetch_value(attrs, &1)})
      |> Map.put(:contract_name, @contract_name)
      |> Map.put(:recovery_action_refs, recovery_action_refs)
    )
  end
end
