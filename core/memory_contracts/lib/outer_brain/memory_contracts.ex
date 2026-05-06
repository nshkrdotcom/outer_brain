defmodule OuterBrain.MemoryContracts do
  @moduledoc """
  Governed memory and context-budget contracts.

  Constructors accept atom or string keys from DTO boundaries, validate bounded
  vocabularies, and reject raw body-bearing fields.
  """

  @raw_payload_keys [
    :body,
    :raw_body,
    :content,
    :raw_content,
    :payload,
    :raw_payload,
    "body",
    "raw_body",
    "content",
    "raw_content",
    "payload",
    "raw_payload"
  ]

  @required_refs [
    :tenant_ref,
    :authority_ref,
    :installation_ref,
    :idempotency_key,
    :trace_ref
  ]

  @redaction_levels [
    :unrestricted,
    :redacted_excerpt_only,
    :hash_only,
    :no_export
  ]

  @memory_tiers [:episodic, :semantic, :working]
  @access_reasons [
    :prompt_grounding,
    :tool_grounding,
    :eval_replay,
    :operator_inspect,
    :audit_recovery,
    :skill_init,
    :hive_handoff
  ]
  @budget_decisions [
    :allow,
    :allow_with_redaction,
    :deny_oversize,
    :deny_exhausted,
    :deny_policy,
    :deny_revoked
  ]
  @budget_reasons [
    :prompt_overflow,
    :tool_overflow,
    :cumulative_overflow,
    :policy_denial,
    :operator_override_denied
  ]

  defmodule MemoryScopeKey do
    @moduledoc "Bounded memory scope key."
    @enforce_keys [:tenant_ref, :installation_ref, :subject_ref]
    defstruct [:tenant_ref, :installation_ref, :subject_ref, :run_ref, :agent_ref, :skill_ref]

    @type t :: %__MODULE__{
            tenant_ref: String.t(),
            installation_ref: String.t(),
            subject_ref: String.t(),
            run_ref: String.t() | nil,
            agent_ref: String.t() | nil,
            skill_ref: String.t() | nil
          }
  end

  defmodule MemoryRef do
    @moduledoc "Opaque memory reference. It never carries raw bodies."
    @enforce_keys [:memory_id, :scope_key, :tier, :revision, :tenant_ref]
    defstruct @enforce_keys

    @type t :: %__MODULE__{
            memory_id: String.t(),
            scope_key: OuterBrain.MemoryContracts.MemoryScopeKey.t(),
            tier: atom(),
            revision: pos_integer(),
            tenant_ref: String.t()
          }
  end

  defmodule MemoryEvidenceRef do
    @moduledoc "Bounded memory evidence reference."
    @enforce_keys [
      :memory_id,
      :evidence_hash,
      :evidence_owner_ref,
      :release_manifest_ref,
      :redaction_policy_ref
    ]
    defstruct @enforce_keys

    @type t :: %__MODULE__{
            memory_id: String.t(),
            evidence_hash: String.t(),
            evidence_owner_ref: String.t(),
            release_manifest_ref: String.t(),
            redaction_policy_ref: String.t()
          }
  end

  defmodule MemoryRedactionPolicy do
    @moduledoc "Bounded redaction policy."
    @enforce_keys [:level, :redaction_policy_ref]
    defstruct @enforce_keys

    @type t :: %__MODULE__{
            level: atom(),
            redaction_policy_ref: String.t()
          }
  end

  defmodule ContextBudgetRef do
    @moduledoc "Opaque context budget ref."
    @enforce_keys [
      :budget_ref,
      :tenant_ref,
      :authority_ref,
      :installation_ref,
      :trace_ref
    ]
    defstruct @enforce_keys

    @type t :: %__MODULE__{
            budget_ref: String.t(),
            tenant_ref: String.t(),
            authority_ref: String.t(),
            installation_ref: String.t(),
            trace_ref: String.t()
          }
  end

  defmodule ContextBudgetDecision do
    @moduledoc "Budget admission decision with bounded result and reason vocabularies."
    @enforce_keys [
      :budget_ref,
      :decision,
      :requested_units,
      :granted_units,
      :residual_units
    ]
    defstruct [:reason | @enforce_keys]

    @type t :: %__MODULE__{
            budget_ref: String.t(),
            decision: atom(),
            reason: atom() | nil,
            requested_units: non_neg_integer(),
            granted_units: non_neg_integer(),
            residual_units: non_neg_integer()
          }
  end

  defmodule MemoryAccessReason do
    @moduledoc "Bounded access reason."
    @enforce_keys [:reason]
    defstruct @enforce_keys

    @type t :: %__MODULE__{reason: atom()}
  end

  defmodule MemoryWriteIntent do
    @moduledoc "Validated governed memory write intent."
    @enforce_keys [
      :tenant_ref,
      :authority_ref,
      :installation_ref,
      :idempotency_key,
      :trace_ref,
      :scope_key,
      :content_class,
      :content_hash,
      :content_redacted_excerpt,
      :redaction_policy,
      :ttl_class,
      :budget_ref
    ]
    defstruct @enforce_keys

    @type t :: %__MODULE__{
            tenant_ref: String.t(),
            authority_ref: String.t(),
            installation_ref: String.t(),
            idempotency_key: String.t(),
            trace_ref: String.t(),
            scope_key: OuterBrain.MemoryContracts.MemoryScopeKey.t(),
            content_class: String.t(),
            content_hash: String.t(),
            content_redacted_excerpt: String.t(),
            redaction_policy: OuterBrain.MemoryContracts.MemoryRedactionPolicy.t(),
            ttl_class: String.t(),
            budget_ref: OuterBrain.MemoryContracts.ContextBudgetRef.t()
          }
  end

  defmodule MemoryQueryIntent do
    @moduledoc "Validated governed memory query intent."
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
            scope_key: OuterBrain.MemoryContracts.MemoryScopeKey.t(),
            query_class: String.t(),
            query_text_hash: String.t(),
            query_redacted_excerpt: String.t(),
            redaction_policy: OuterBrain.MemoryContracts.MemoryRedactionPolicy.t(),
            max_results: pos_integer(),
            budget_ref: OuterBrain.MemoryContracts.ContextBudgetRef.t()
          }
  end

  @type error :: {:error, term()}

  @spec redaction_levels() :: [atom()]
  def redaction_levels, do: @redaction_levels

  @spec memory_tiers() :: [atom()]
  def memory_tiers, do: @memory_tiers

  @spec access_reasons() :: [atom()]
  def access_reasons, do: @access_reasons

  @spec budget_decisions() :: [atom()]
  def budget_decisions, do: @budget_decisions

  @spec budget_exhaustion_reasons() :: [atom()]
  def budget_exhaustion_reasons, do: @budget_reasons

  @spec scope_key(map() | MemoryScopeKey.t()) :: {:ok, MemoryScopeKey.t()} | error()
  def scope_key(%MemoryScopeKey{} = scope), do: {:ok, scope}

  def scope_key(attrs) when is_map(attrs) do
    with :ok <- reject_raw_payload(attrs),
         {:ok, tenant_ref} <- required_string(attrs, :tenant_ref),
         {:ok, installation_ref} <- required_string(attrs, :installation_ref),
         {:ok, subject_ref} <- required_string(attrs, :subject_ref),
         :ok <- bounded_optional_refs(attrs, [:run_ref, :agent_ref, :skill_ref]) do
      {:ok,
       %MemoryScopeKey{
         tenant_ref: tenant_ref,
         installation_ref: installation_ref,
         subject_ref: subject_ref,
         run_ref: optional_string(attrs, :run_ref),
         agent_ref: optional_string(attrs, :agent_ref),
         skill_ref: optional_string(attrs, :skill_ref)
       }}
    end
  end

  def scope_key(_attrs), do: {:error, :invalid_memory_scope_key}

  @spec memory_ref(map() | MemoryRef.t()) :: {:ok, MemoryRef.t()} | error()
  def memory_ref(%MemoryRef{} = ref), do: {:ok, ref}

  def memory_ref(attrs) when is_map(attrs) do
    with :ok <- reject_raw_payload(attrs),
         {:ok, memory_id} <- required_string(attrs, :memory_id),
         {:ok, scope_key} <- attrs |> fetch_value(:scope_key) |> scope_key(),
         {:ok, tier} <- required_member(attrs, :tier, @memory_tiers),
         {:ok, revision} <- required_positive_integer(attrs, :revision),
         {:ok, tenant_ref} <- required_string(attrs, :tenant_ref) do
      {:ok,
       %MemoryRef{
         memory_id: memory_id,
         scope_key: scope_key,
         tier: tier,
         revision: revision,
         tenant_ref: tenant_ref
       }}
    end
  end

  def memory_ref(_attrs), do: {:error, :invalid_memory_ref}

  @spec evidence_ref(map() | MemoryEvidenceRef.t()) :: {:ok, MemoryEvidenceRef.t()} | error()
  def evidence_ref(%MemoryEvidenceRef{} = ref), do: {:ok, ref}

  def evidence_ref(attrs) when is_map(attrs) do
    with :ok <- reject_raw_payload(attrs),
         {:ok, memory_id} <- required_string(attrs, :memory_id),
         {:ok, evidence_hash} <- required_string(attrs, :evidence_hash),
         {:ok, evidence_owner_ref} <- required_string(attrs, :evidence_owner_ref),
         {:ok, release_manifest_ref} <- required_string(attrs, :release_manifest_ref),
         {:ok, redaction_policy_ref} <- required_string(attrs, :redaction_policy_ref) do
      {:ok,
       %MemoryEvidenceRef{
         memory_id: memory_id,
         evidence_hash: evidence_hash,
         evidence_owner_ref: evidence_owner_ref,
         release_manifest_ref: release_manifest_ref,
         redaction_policy_ref: redaction_policy_ref
       }}
    end
  end

  def evidence_ref(_attrs), do: {:error, :invalid_memory_evidence_ref}

  @spec redaction_policy(map() | MemoryRedactionPolicy.t()) ::
          {:ok, MemoryRedactionPolicy.t()} | error()
  def redaction_policy(%MemoryRedactionPolicy{} = policy), do: {:ok, policy}

  def redaction_policy(attrs) when is_map(attrs) do
    with {:ok, level} <- required_member(attrs, :level, @redaction_levels),
         {:ok, redaction_policy_ref} <- required_string(attrs, :redaction_policy_ref) do
      {:ok, %MemoryRedactionPolicy{level: level, redaction_policy_ref: redaction_policy_ref}}
    end
  end

  def redaction_policy(level) when level in @redaction_levels do
    {:ok,
     %MemoryRedactionPolicy{
       level: level,
       redaction_policy_ref: "memory-redaction-policy://#{level}"
     }}
  end

  def redaction_policy(_attrs), do: {:error, :invalid_memory_redaction_policy}

  @spec access_reason(map() | atom() | MemoryAccessReason.t()) ::
          {:ok, MemoryAccessReason.t()} | error()
  def access_reason(%MemoryAccessReason{} = reason), do: {:ok, reason}

  def access_reason(reason) when reason in @access_reasons,
    do: {:ok, %MemoryAccessReason{reason: reason}}

  def access_reason(attrs) when is_map(attrs) do
    with {:ok, reason} <- required_member(attrs, :reason, @access_reasons) do
      {:ok, %MemoryAccessReason{reason: reason}}
    end
  end

  def access_reason(_reason), do: {:error, :unknown_memory_access_reason}

  @spec budget_ref(map() | ContextBudgetRef.t()) :: {:ok, ContextBudgetRef.t()} | error()
  def budget_ref(%ContextBudgetRef{} = ref), do: {:ok, ref}

  def budget_ref(attrs) when is_map(attrs) do
    with {:ok, budget_ref} <- required_string(attrs, :budget_ref),
         {:ok, tenant_ref} <- required_string(attrs, :tenant_ref),
         {:ok, authority_ref} <- required_string(attrs, :authority_ref),
         {:ok, installation_ref} <- required_string(attrs, :installation_ref),
         {:ok, trace_ref} <- required_string(attrs, :trace_ref) do
      {:ok,
       %ContextBudgetRef{
         budget_ref: budget_ref,
         tenant_ref: tenant_ref,
         authority_ref: authority_ref,
         installation_ref: installation_ref,
         trace_ref: trace_ref
       }}
    end
  end

  def budget_ref(_attrs), do: {:error, :invalid_context_budget_ref}

  @spec budget_decision(map() | ContextBudgetDecision.t()) ::
          {:ok, ContextBudgetDecision.t()} | error()
  def budget_decision(%ContextBudgetDecision{} = decision), do: {:ok, decision}

  def budget_decision(attrs) when is_map(attrs) do
    with {:ok, budget_ref} <- required_string(attrs, :budget_ref),
         {:ok, decision} <- required_member(attrs, :decision, @budget_decisions),
         {:ok, requested_units} <- required_non_negative_integer(attrs, :requested_units),
         {:ok, granted_units} <- required_non_negative_integer(attrs, :granted_units),
         {:ok, residual_units} <- required_non_negative_integer(attrs, :residual_units),
         :ok <- allowed_decision_reason(attrs, decision) do
      {:ok,
       %ContextBudgetDecision{
         budget_ref: budget_ref,
         decision: decision,
         reason: optional_member(attrs, :reason, @budget_reasons),
         requested_units: requested_units,
         granted_units: granted_units,
         residual_units: residual_units
       }}
    end
  end

  def budget_decision(_attrs), do: {:error, :invalid_context_budget_decision}

  @spec write_intent(map() | MemoryWriteIntent.t()) :: {:ok, MemoryWriteIntent.t()} | error()
  def write_intent(%MemoryWriteIntent{} = intent), do: {:ok, intent}

  def write_intent(attrs) when is_map(attrs) do
    with :ok <- reject_raw_payload(attrs),
         :ok <- required_ref_fields(attrs),
         {:ok, scope_key} <- attrs |> fetch_value(:scope_key) |> scope_key(),
         {:ok, redaction_policy} <- attrs |> fetch_value(:redaction_policy) |> redaction_policy(),
         {:ok, budget_ref} <- attrs |> fetch_value(:budget_ref) |> budget_ref(),
         {:ok, content_class} <- required_string(attrs, :content_class),
         {:ok, content_hash} <- required_string(attrs, :content_hash),
         {:ok, content_redacted_excerpt} <- required_string(attrs, :content_redacted_excerpt),
         {:ok, ttl_class} <- required_string(attrs, :ttl_class) do
      {:ok,
       %MemoryWriteIntent{
         tenant_ref: fetch_value(attrs, :tenant_ref),
         authority_ref: fetch_value(attrs, :authority_ref),
         installation_ref: fetch_value(attrs, :installation_ref),
         idempotency_key: fetch_value(attrs, :idempotency_key),
         trace_ref: fetch_value(attrs, :trace_ref),
         scope_key: scope_key,
         content_class: content_class,
         content_hash: content_hash,
         content_redacted_excerpt: content_redacted_excerpt,
         redaction_policy: redaction_policy,
         ttl_class: ttl_class,
         budget_ref: budget_ref
       }}
    end
  end

  def write_intent(_attrs), do: {:error, :invalid_memory_write_intent}

  @spec query_intent(map() | MemoryQueryIntent.t()) :: {:ok, MemoryQueryIntent.t()} | error()
  def query_intent(%MemoryQueryIntent{} = intent), do: {:ok, intent}

  def query_intent(attrs) when is_map(attrs) do
    with :ok <- reject_raw_payload(attrs),
         :ok <- required_ref_fields(attrs),
         {:ok, scope_key} <- attrs |> fetch_value(:scope_key) |> scope_key(),
         {:ok, redaction_policy} <- attrs |> fetch_value(:redaction_policy) |> redaction_policy(),
         {:ok, budget_ref} <- attrs |> fetch_value(:budget_ref) |> budget_ref(),
         {:ok, query_class} <- required_string(attrs, :query_class),
         {:ok, query_text_hash} <- required_string(attrs, :query_text_hash),
         {:ok, query_redacted_excerpt} <- required_string(attrs, :query_redacted_excerpt),
         {:ok, max_results} <- required_positive_integer(attrs, :max_results) do
      {:ok,
       %MemoryQueryIntent{
         tenant_ref: fetch_value(attrs, :tenant_ref),
         authority_ref: fetch_value(attrs, :authority_ref),
         installation_ref: fetch_value(attrs, :installation_ref),
         idempotency_key: fetch_value(attrs, :idempotency_key),
         trace_ref: fetch_value(attrs, :trace_ref),
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

  def query_intent(_attrs), do: {:error, :invalid_memory_query_intent}

  @spec fetch_value(map(), atom()) :: term()
  def fetch_value(attrs, field) when is_map(attrs) and is_atom(field) do
    Map.get(attrs, field) || Map.get(attrs, Atom.to_string(field))
  end

  defp required_ref_fields(attrs) do
    case Enum.find(@required_refs, &(required_string(attrs, &1) != {:ok, fetch_value(attrs, &1)})) do
      nil -> :ok
      field -> {:error, {:missing_required_ref, field}}
    end
  end

  defp required_string(attrs, field) do
    case fetch_value(attrs, field) do
      value when is_binary(value) ->
        if String.trim(value) == "", do: {:error, {:missing_field, field}}, else: {:ok, value}

      _other ->
        {:error, {:missing_field, field}}
    end
  end

  defp optional_string(attrs, field) do
    case fetch_value(attrs, field) do
      value when is_binary(value) and value != "" -> value
      _other -> nil
    end
  end

  defp bounded_optional_refs(attrs, fields) do
    case Enum.find(fields, fn field ->
           value = fetch_value(attrs, field)
           not (is_nil(value) or (is_binary(value) and String.trim(value) != ""))
         end) do
      nil -> :ok
      field -> {:error, {:invalid_scope_ref, field}}
    end
  end

  defp required_member(attrs, field, allowed) do
    value = fetch_value(attrs, field)

    if value in allowed do
      {:ok, value}
    else
      {:error, {:invalid_field, field}}
    end
  end

  defp optional_member(attrs, field, allowed) do
    value = fetch_value(attrs, field)
    if value in allowed, do: value
  end

  defp required_positive_integer(attrs, field) do
    case fetch_value(attrs, field) do
      value when is_integer(value) and value > 0 -> {:ok, value}
      _other -> {:error, {:invalid_field, field}}
    end
  end

  defp required_non_negative_integer(attrs, field) do
    case fetch_value(attrs, field) do
      value when is_integer(value) and value >= 0 -> {:ok, value}
      _other -> {:error, {:invalid_field, field}}
    end
  end

  defp allowed_decision_reason(attrs, decision) do
    reason = fetch_value(attrs, :reason)

    cond do
      decision in [:allow, :allow_with_redaction] and is_nil(reason) -> :ok
      decision in [:allow, :allow_with_redaction] -> {:error, :unexpected_budget_denial_reason}
      reason in @budget_reasons -> :ok
      true -> {:error, :missing_budget_denial_reason}
    end
  end

  defp reject_raw_payload(attrs) when is_map(attrs) do
    case Enum.find(@raw_payload_keys, &Map.has_key?(attrs, &1)) do
      nil -> :ok
      key -> {:error, {:raw_memory_body_forbidden, key}}
    end
  end
end
