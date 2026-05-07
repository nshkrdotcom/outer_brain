defmodule OuterBrain.Contracts.SemanticDuplicateSuppression do
  @moduledoc """
  Phase 4 duplicate semantic work suppression contract.

  Duplicate suppression must be deterministic, idempotent, and operator-visible;
  hidden suppression is a contract violation.
  """

  alias OuterBrain.Contracts.{PersistencePosture, Phase4SemanticContract}

  @contract_name "OuterBrain.SemanticDuplicateSuppression.v1"
  @visibility ["visible"]
  @fields Phase4SemanticContract.scope_fields() ++
            [
              :principal_ref,
              :system_actor_ref,
              :semantic_idempotency_key,
              :semantic_ref,
              :suppression_ref,
              :duplicate_of_ref,
              :routing_fact_hash,
              :publication_ref,
              :operator_visibility,
              :reason_code,
              :persistence_posture
            ]

  @required_strings [
    :semantic_idempotency_key,
    :semantic_ref,
    :suppression_ref,
    :duplicate_of_ref,
    :routing_fact_hash,
    :publication_ref,
    :reason_code
  ]

  defstruct [:contract_name | @fields]

  @type t :: %__MODULE__{}

  @spec new(map() | t()) :: {:ok, t()} | {:error, term()}
  def new(%__MODULE__{} = contract), do: contract |> to_map() |> new()

  def new(attrs) when is_map(attrs) do
    with :ok <- Phase4SemanticContract.required_scope(attrs),
         :ok <- Phase4SemanticContract.required_strings(attrs, @required_strings),
         :ok <- Phase4SemanticContract.string_enum(attrs, :operator_visibility, @visibility) do
      {:ok, build(attrs)}
    end
  end

  def new(_attrs), do: {:error, :invalid_semantic_duplicate_suppression}

  @spec to_map(t()) :: map()
  def to_map(%__MODULE__{} = contract),
    do: Map.from_struct(contract) |> Map.delete(:contract_name)

  defp build(attrs) do
    struct!(
      __MODULE__,
      Map.new(@fields, &{&1, Phase4SemanticContract.fetch_value(attrs, &1)})
      |> Map.put(:contract_name, @contract_name)
      |> Map.put(:persistence_posture, PersistencePosture.resolve(:duplicate_suppression, attrs))
    )
  end
end
