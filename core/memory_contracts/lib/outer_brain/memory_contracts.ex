defmodule OuterBrain.MemoryContracts do
  @moduledoc """
  Governed memory and context-budget contracts.

  Constructors accept atom or string keys from DTO boundaries, validate bounded
  vocabularies, and reject raw body-bearing fields. The public facade remains
  intentionally small; identity, evidence, policy, budget, and intent
  contracts live in focused modules under `OuterBrain.MemoryContracts`.
  """

  alias OuterBrain.MemoryContracts.{
    ContextBudgetDecision,
    ContextBudgetRef,
    MemoryAccessReason,
    MemoryEvidenceRef,
    MemoryQueryIntent,
    MemoryRedactionPolicy,
    MemoryRef,
    MemoryScopeKey,
    MemoryWriteIntent,
    Validator,
    Vocabulary
  }

  @type error :: {:error, term()}

  @spec redaction_levels() :: [atom()]
  def redaction_levels, do: Vocabulary.redaction_levels()

  @spec memory_tiers() :: [atom()]
  def memory_tiers, do: Vocabulary.memory_tiers()

  @spec access_reasons() :: [atom()]
  def access_reasons, do: Vocabulary.access_reasons()

  @spec budget_decisions() :: [atom()]
  def budget_decisions, do: Vocabulary.budget_decisions()

  @spec budget_exhaustion_reasons() :: [atom()]
  def budget_exhaustion_reasons, do: Vocabulary.budget_exhaustion_reasons()

  @spec scope_key(map() | MemoryScopeKey.t()) :: {:ok, MemoryScopeKey.t()} | error()
  def scope_key(attrs), do: MemoryScopeKey.new(attrs)

  @spec memory_ref(map() | MemoryRef.t()) :: {:ok, MemoryRef.t()} | error()
  def memory_ref(attrs), do: MemoryRef.new(attrs)

  @spec evidence_ref(map() | MemoryEvidenceRef.t()) :: {:ok, MemoryEvidenceRef.t()} | error()
  def evidence_ref(attrs), do: MemoryEvidenceRef.new(attrs)

  @spec redaction_policy(map() | atom() | MemoryRedactionPolicy.t()) ::
          {:ok, MemoryRedactionPolicy.t()} | error()
  def redaction_policy(attrs), do: MemoryRedactionPolicy.new(attrs)

  @spec access_reason(map() | atom() | MemoryAccessReason.t()) ::
          {:ok, MemoryAccessReason.t()} | error()
  def access_reason(attrs), do: MemoryAccessReason.new(attrs)

  @spec budget_ref(map() | ContextBudgetRef.t()) :: {:ok, ContextBudgetRef.t()} | error()
  def budget_ref(attrs), do: ContextBudgetRef.new(attrs)

  @spec budget_decision(map() | ContextBudgetDecision.t()) ::
          {:ok, ContextBudgetDecision.t()} | error()
  def budget_decision(attrs), do: ContextBudgetDecision.new(attrs)

  @spec write_intent(map() | MemoryWriteIntent.t()) :: {:ok, MemoryWriteIntent.t()} | error()
  def write_intent(attrs), do: MemoryWriteIntent.new(attrs)

  @spec query_intent(map() | MemoryQueryIntent.t()) :: {:ok, MemoryQueryIntent.t()} | error()
  def query_intent(attrs), do: MemoryQueryIntent.new(attrs)

  @spec fetch_value(map(), atom()) :: term()
  def fetch_value(attrs, field), do: Validator.fetch_value(attrs, field)
end
