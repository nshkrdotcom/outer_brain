defmodule OuterBrain.MemoryEngine do
  @moduledoc """
  Governed memory-default engine.

  The engine stores refs, hashes, bounded excerpts, and policy metadata only.
  Raw bodies are accepted at the write boundary solely to derive hash evidence
  and are not retained in returned projections.
  """

  alias OuterBrain.{GuardrailEngine, MemoryContracts}

  defmodule Store do
    @moduledoc "In-memory store state."
    @enforce_keys [:adapter, :entries, :revision_counter]
    defstruct @enforce_keys

    @type t :: %__MODULE__{
            adapter: atom(),
            entries: map(),
            revision_counter: non_neg_integer()
          }
  end

  defmodule AdapterRegistry do
    @moduledoc "Explicit adapter registry."
    defstruct registered: [:memory_default]

    @type t :: %__MODULE__{registered: [atom()]}
  end

  @memory_default :memory_default
  @tiers [:episodic, :semantic, :working]
  @eviction_reasons [
    :ttl_expired,
    :revision_replaced,
    :run_terminal,
    :policy_redacted,
    :operator_evicted,
    :tenant_revoked
  ]

  @spec new(keyword()) :: Store.t()
  def new(opts \\ []) when is_list(opts) do
    adapter = Keyword.get(opts, :adapter, @memory_default)
    %Store{adapter: adapter, entries: %{}, revision_counter: 0}
  end

  @spec select_adapter(AdapterRegistry.t(), atom()) :: :ok | {:error, term()}
  def select_adapter(%AdapterRegistry{registered: registered}, adapter) do
    if adapter in registered do
      :ok
    else
      {:error, {:unregistered_memory_adapter, adapter}}
    end
  end

  @spec write(Store.t(), map(), String.t(), keyword()) ::
          {:ok, Store.t(), MemoryContracts.MemoryRef.t(), MemoryContracts.MemoryEvidenceRef.t()}
          | {:error, term()}
  def write(store, attrs, raw_body, opts \\ [])

  def write(%Store{} = store, attrs, raw_body, opts)
      when is_binary(raw_body) and is_list(opts) do
    max_export_bytes = Keyword.get(opts, :max_export_bytes, 512)

    with :ok <- select_adapter(%AdapterRegistry{}, store.adapter),
         :ok <- guard_memory_candidate(raw_body, attrs, opts),
         {:ok, intent} <- MemoryContracts.write_intent(attrs),
         :ok <- tier_allowed(intent.scope_key),
         {:ok, evidence_hash, excerpt} <- evidence(raw_body, max_export_bytes),
         revision = store.revision_counter + 1,
         memory_id = memory_id(intent.tenant_ref, intent.content_hash, revision),
         {:ok, memory_ref} <-
           MemoryContracts.memory_ref(%{
             memory_id: memory_id,
             scope_key: intent.scope_key,
             tier: scope_tier(intent.scope_key),
             revision: revision,
             tenant_ref: intent.tenant_ref
           }),
         {:ok, evidence_ref} <-
           MemoryContracts.evidence_ref(%{
             memory_id: memory_id,
             evidence_hash: evidence_hash,
             evidence_owner_ref: "outer-brain-memory-engine://evidence",
             release_manifest_ref: "release://phase-a-memory",
             redaction_policy_ref: intent.redaction_policy.redaction_policy_ref
           }) do
      entry = %{
        memory_ref: memory_ref,
        evidence_ref: evidence_ref,
        scope_key: intent.scope_key,
        tenant_ref: intent.tenant_ref,
        installation_ref: intent.installation_ref,
        content_class: intent.content_class,
        content_hash: intent.content_hash,
        redacted_excerpt: excerpt,
        ttl_class: intent.ttl_class,
        evicted?: false
      }

      {:ok, put_entry(store, memory_id, entry), memory_ref, evidence_ref}
    end
  end

  def write(%Store{}, _attrs, _raw_body, _opts), do: {:error, :invalid_memory_body}

  @spec query(Store.t(), map()) :: {:ok, [map()]} | {:error, term()}
  def query(%Store{} = store, attrs) when is_map(attrs) do
    with {:ok, intent} <- MemoryContracts.query_intent(attrs) do
      matches =
        store.entries
        |> Map.values()
        |> Enum.reject(& &1.evicted?)
        |> Enum.filter(&scope_matches?(&1, intent))
        |> Enum.take(intent.max_results)
        |> Enum.map(&project_entry/1)

      {:ok, matches}
    end
  end

  @spec evict(Store.t(), MemoryContracts.MemoryRef.t() | String.t(), atom()) ::
          {:ok, Store.t(), map()} | {:error, term()}
  def evict(%Store{} = store, %MemoryContracts.MemoryRef{memory_id: memory_id}, reason) do
    evict(store, memory_id, reason)
  end

  def evict(%Store{} = store, memory_id, reason)
      when is_binary(memory_id) and reason in @eviction_reasons do
    case Map.fetch(store.entries, memory_id) do
      {:ok, entry} ->
        updated_entry = Map.put(entry, :evicted?, true)
        receipt = %{memory_id: memory_id, eviction_reason: reason, raw_body: nil}
        {:ok, %Store{store | entries: Map.put(store.entries, memory_id, updated_entry)}, receipt}

      :error ->
        {:error, :unknown_memory_id}
    end
  end

  def evict(%Store{}, _memory_id, _reason), do: {:error, :invalid_eviction_reason}

  @spec project(Store.t(), MemoryContracts.MemoryRef.t() | String.t()) ::
          {:ok, map()} | {:error, term()}
  def project(%Store{} = store, %MemoryContracts.MemoryRef{memory_id: memory_id}),
    do: project(store, memory_id)

  def project(%Store{} = store, memory_id) when is_binary(memory_id) do
    case Map.fetch(store.entries, memory_id) do
      {:ok, entry} -> {:ok, project_entry(entry)}
      :error -> {:error, :unknown_memory_id}
    end
  end

  @spec redact(Store.t(), MemoryContracts.MemoryRef.t() | String.t()) ::
          {:ok, Store.t(), map()} | {:error, term()}
  def redact(%Store{} = store, %MemoryContracts.MemoryRef{memory_id: memory_id}),
    do: redact(store, memory_id)

  def redact(%Store{} = store, memory_id) when is_binary(memory_id) do
    case Map.fetch(store.entries, memory_id) do
      {:ok, entry} ->
        updated_entry = %{entry | redacted_excerpt: nil}
        receipt = %{memory_id: memory_id, redaction: :hash_only}
        {:ok, %Store{store | entries: Map.put(store.entries, memory_id, updated_entry)}, receipt}

      :error ->
        {:error, :unknown_memory_id}
    end
  end

  defp evidence(raw_body, max_export_bytes) when byte_size(raw_body) > max_export_bytes do
    {:ok, sha256(raw_body), "body_oversize_replaced_by_hash_ref"}
  end

  defp evidence(raw_body, _max_export_bytes), do: {:ok, sha256(raw_body), raw_body}

  defp guard_memory_candidate(raw_body, _attrs, opts) do
    guard_attrs = Keyword.get(opts, :guard_attrs)
    require_guard? = Keyword.get(opts, :require_guard?, false)

    cond do
      is_map(guard_attrs) ->
        case GuardrailEngine.evaluate(:memory_candidate, raw_body, guard_attrs) do
          {:ok, %{decision_class: decision_class, redaction_posture: posture}}
          when decision_class in [:allow, :allow_with_redaction] and
                 posture in [:pass, :partial, :excerpt_only] ->
            :ok

          {:ok, decision} ->
            {:error,
             {:memory_candidate_guard_denied, decision.decision_class, decision.redaction_posture}}

          {:error, reason} ->
            {:error, {:memory_candidate_guard_failed, reason}}
        end

      require_guard? ->
        {:error, :memory_candidate_guard_required}

      true ->
        :ok
    end
  end

  defp sha256(value),
    do: "sha256:" <> (:crypto.hash(:sha256, value) |> Base.encode16(case: :lower))

  defp memory_id(tenant_ref, content_hash, revision) do
    seed = tenant_ref <> ":" <> content_hash <> ":" <> Integer.to_string(revision)
    "memory://" <> Base.encode16(:crypto.hash(:sha256, seed), case: :lower)
  end

  defp put_entry(%Store{} = store, memory_id, entry) do
    %Store{
      store
      | entries: Map.put(store.entries, memory_id, entry),
        revision_counter: store.revision_counter + 1
    }
  end

  defp scope_matches?(entry, intent) do
    entry.tenant_ref == intent.tenant_ref and
      entry.installation_ref == intent.installation_ref and
      entry.scope_key == intent.scope_key
  end

  defp project_entry(entry) do
    %{
      memory_ref: entry.memory_ref,
      evidence_ref: entry.evidence_ref,
      content_class: entry.content_class,
      content_hash: entry.content_hash,
      redacted_excerpt: entry.redacted_excerpt,
      evicted?: entry.evicted?
    }
  end

  defp tier_allowed(%MemoryContracts.MemoryScopeKey{} = scope_key) do
    if scope_tier(scope_key) in @tiers, do: :ok, else: {:error, :unknown_memory_tier}
  end

  defp scope_tier(%MemoryContracts.MemoryScopeKey{run_ref: nil, agent_ref: nil}), do: :semantic
  defp scope_tier(%MemoryContracts.MemoryScopeKey{skill_ref: nil}), do: :episodic
  defp scope_tier(%MemoryContracts.MemoryScopeKey{}), do: :working
end
