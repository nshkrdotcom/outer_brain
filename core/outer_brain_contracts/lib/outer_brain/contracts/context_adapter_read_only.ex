defmodule OuterBrain.Contracts.ContextAdapterReadOnly do
  @moduledoc """
  Phase 4 context adapter read-only descriptor.

  Context adapters contribute provenance-bearing context fragments. They do not
  receive write grants and cannot mutate lower, product, or semantic truth.
  """

  alias OuterBrain.Contracts.Phase4SemanticContract

  @contract_name "OuterBrain.ContextAdapterReadOnly.v1"
  @fields Phase4SemanticContract.scope_fields() ++
            [
              :principal_ref,
              :system_actor_ref,
              :adapter_ref,
              :allowed_read_resources,
              :denied_write_resources,
              :read_claim_check_ref,
              :mutation_scan_ref,
              :mutation_permissions
            ]

  @required_strings [:adapter_ref, :read_claim_check_ref, :mutation_scan_ref]

  defstruct [:contract_name | @fields]

  @type t :: %__MODULE__{}

  @spec new(map() | t()) :: {:ok, t()} | {:error, term()}
  def new(%__MODULE__{} = contract), do: contract |> to_map() |> new()

  def new(attrs) when is_map(attrs) do
    with :ok <- Phase4SemanticContract.required_scope(attrs),
         :ok <- Phase4SemanticContract.required_strings(attrs, @required_strings),
         {:ok, allowed_reads} <-
           Phase4SemanticContract.required_non_empty_list(attrs, :allowed_read_resources),
         {:ok, denied_writes} <-
           Phase4SemanticContract.required_non_empty_list(attrs, :denied_write_resources),
         :ok <- reject_mutation_permissions(attrs) do
      {:ok, build(attrs, allowed_reads, denied_writes)}
    end
  end

  def new(_attrs), do: {:error, :invalid_context_adapter_read_only}

  @spec to_map(t()) :: map()
  def to_map(%__MODULE__{} = contract),
    do: Map.from_struct(contract) |> Map.delete(:contract_name)

  defp reject_mutation_permissions(attrs) do
    case Phase4SemanticContract.list_value(attrs, :mutation_permissions) do
      [] -> :ok
      _permissions -> {:error, {:read_only_violation, :mutation_permissions}}
    end
  end

  defp build(attrs, allowed_reads, denied_writes) do
    struct!(
      __MODULE__,
      Map.new(@fields, &{&1, Phase4SemanticContract.fetch_value(attrs, &1)})
      |> Map.put(:contract_name, @contract_name)
      |> Map.put(:allowed_read_resources, allowed_reads)
      |> Map.put(:denied_write_resources, denied_writes)
      |> Map.put(:mutation_permissions, [])
    )
  end
end
