defmodule OuterBrain.MemoryContracts.MemoryQueryIntent do
  @moduledoc "Validated governed memory query intent."

  alias OuterBrain.MemoryContracts.{
    ContextBudgetRef,
    MemoryRedactionPolicy,
    MemoryScopeKey,
    Validator
  }

  @enforce_keys [
    :tenant_ref,
    :authority_ref,
    :installation_ref,
    :idempotency_key,
    :trace_ref,
    :scope_key,
    :query_class,
    :query_text_hash,
    :query_redacted_excerpt,
    :redaction_policy,
    :max_results,
    :budget_ref
  ]
  defstruct @enforce_keys

  @type t :: %__MODULE__{
          tenant_ref: String.t(),
          authority_ref: String.t(),
          installation_ref: String.t(),
          idempotency_key: String.t(),
          trace_ref: String.t(),
          scope_key: MemoryScopeKey.t(),
          query_class: String.t(),
          query_text_hash: String.t(),
          query_redacted_excerpt: String.t(),
          redaction_policy: MemoryRedactionPolicy.t(),
          max_results: pos_integer(),
          budget_ref: ContextBudgetRef.t()
        }

  @spec new(map() | t()) :: {:ok, t()} | {:error, term()}
  def new(%__MODULE__{} = intent), do: {:ok, intent}

  def new(attrs) when is_map(attrs) do
    with :ok <- Validator.reject_raw_payload(attrs),
         :ok <- Validator.required_ref_fields(attrs),
         {:ok, scope_key} <- attrs |> Validator.fetch_value(:scope_key) |> MemoryScopeKey.new(),
         {:ok, redaction_policy} <-
           attrs |> Validator.fetch_value(:redaction_policy) |> MemoryRedactionPolicy.new(),
         {:ok, budget_ref} <-
           attrs |> Validator.fetch_value(:budget_ref) |> ContextBudgetRef.new(),
         {:ok, query_class} <- Validator.required_string(attrs, :query_class),
         {:ok, query_text_hash} <- Validator.required_string(attrs, :query_text_hash),
         {:ok, query_redacted_excerpt} <-
           Validator.required_string(attrs, :query_redacted_excerpt),
         {:ok, max_results} <- Validator.required_positive_integer(attrs, :max_results) do
      {:ok,
       %__MODULE__{
         tenant_ref: Validator.fetch_value(attrs, :tenant_ref),
         authority_ref: Validator.fetch_value(attrs, :authority_ref),
         installation_ref: Validator.fetch_value(attrs, :installation_ref),
         idempotency_key: Validator.fetch_value(attrs, :idempotency_key),
         trace_ref: Validator.fetch_value(attrs, :trace_ref),
         scope_key: scope_key,
         query_class: query_class,
         query_text_hash: query_text_hash,
         query_redacted_excerpt: query_redacted_excerpt,
         redaction_policy: redaction_policy,
         max_results: max_results,
         budget_ref: budget_ref
       }}
    end
  end

  def new(_attrs), do: {:error, :invalid_memory_query_intent}
end
