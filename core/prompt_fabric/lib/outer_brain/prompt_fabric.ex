defmodule OuterBrain.PromptFabric do
  @moduledoc """
  Governed prompt artifacts with immutable revisions and bounded projections.
  """

  @raw_payload_keys [
    :body,
    :raw_body,
    :prompt_body,
    :raw_prompt,
    :content,
    :raw_content,
    "body",
    "raw_body",
    "prompt_body",
    "raw_prompt",
    "content",
    "raw_content"
  ]

  @derivation_reasons [:author, :auto_promote, :rollback, :ab_split, :ab_collapse]
  @resolve_decisions [
    :resolved,
    :resolved_with_redaction,
    :denied_revoked,
    :denied_revision_missing,
    :denied_ab_assignment_invalid,
    :denied_policy
  ]
  @redaction_levels [:unrestricted, :redacted_excerpt_only, :hash_only, :no_export]

  defmodule Store do
    @moduledoc "Prompt fabric in-memory state."
    defstruct prompts: %{}
    @type t :: %__MODULE__{prompts: map()}
  end

  defmodule PromptArtifactRef do
    @moduledoc "Prompt artifact ref without raw prompt body."
    @enforce_keys [
      :prompt_id,
      :revision,
      :tenant_ref,
      :installation_ref,
      :content_hash,
      :redaction_policy_ref,
      :lineage_ref
    ]
    defstruct @enforce_keys

    @type t :: %__MODULE__{
            prompt_id: String.t(),
            revision: pos_integer(),
            tenant_ref: String.t(),
            installation_ref: String.t(),
            content_hash: String.t(),
            redaction_policy_ref: String.t(),
            lineage_ref: String.t()
          }
  end

  defmodule PromptLineageRef do
    @moduledoc "Prompt lineage ref."
    @enforce_keys [
      :lineage_ref,
      :prompt_id,
      :revision,
      :derivation_reason,
      :decision_evidence_ref
    ]
    defstruct [:parent_revision | @enforce_keys]

    @type t :: %__MODULE__{
            lineage_ref: String.t(),
            prompt_id: String.t(),
            revision: pos_integer(),
            parent_revision: pos_integer() | nil,
            derivation_reason: atom(),
            decision_evidence_ref: String.t()
          }
  end

  defmodule PromptResolveIntent do
    @moduledoc "Prompt resolution intent."
    @enforce_keys [
      :tenant_ref,
      :authority_ref,
      :installation_ref,
      :idempotency_key,
      :trace_ref,
      :prompt_id,
      :requested_revision,
      :ab_assignment_key,
      :resolution_policy
    ]
    defstruct @enforce_keys

    @type t :: %__MODULE__{
            tenant_ref: String.t(),
            authority_ref: String.t(),
            installation_ref: String.t(),
            idempotency_key: String.t(),
            trace_ref: String.t(),
            prompt_id: String.t(),
            requested_revision: pos_integer(),
            ab_assignment_key: String.t(),
            resolution_policy: String.t()
          }
  end

  defmodule PromptResolveDecision do
    @moduledoc "Prompt resolution decision."
    @enforce_keys [:prompt_ref, :decision_class, :trace_ref]
    defstruct @enforce_keys

    @type t :: %__MODULE__{
            prompt_ref: PromptArtifactRef.t(),
            decision_class: atom(),
            trace_ref: String.t()
          }
  end

  @spec new() :: Store.t()
  def new, do: %Store{}

  @spec artifact_ref(map()) :: {:ok, PromptArtifactRef.t()} | {:error, term()}
  def artifact_ref(attrs) when is_map(attrs) do
    with :ok <- reject_raw_payload(attrs),
         :ok <-
           required_strings(attrs, [
             :prompt_id,
             :tenant_ref,
             :installation_ref,
             :content_hash,
             :redaction_policy_ref,
             :lineage_ref
           ]),
         {:ok, revision} <- positive_integer(attrs, :revision) do
      {:ok,
       %PromptArtifactRef{
         prompt_id: fetch!(attrs, :prompt_id),
         revision: revision,
         tenant_ref: fetch!(attrs, :tenant_ref),
         installation_ref: fetch!(attrs, :installation_ref),
         content_hash: fetch!(attrs, :content_hash),
         redaction_policy_ref: fetch!(attrs, :redaction_policy_ref),
         lineage_ref: fetch!(attrs, :lineage_ref)
       }}
    end
  end

  @spec lineage_ref(map()) :: {:ok, PromptLineageRef.t()} | {:error, term()}
  def lineage_ref(attrs) when is_map(attrs) do
    with :ok <- required_strings(attrs, [:lineage_ref, :prompt_id, :decision_evidence_ref]),
         {:ok, revision} <- positive_integer(attrs, :revision),
         {:ok, reason} <- derivation_reason(fetch(attrs, :derivation_reason)) do
      {:ok,
       %PromptLineageRef{
         lineage_ref: fetch!(attrs, :lineage_ref),
         prompt_id: fetch!(attrs, :prompt_id),
         revision: revision,
         parent_revision: fetch(attrs, :parent_revision),
         derivation_reason: reason,
         decision_evidence_ref: fetch!(attrs, :decision_evidence_ref)
       }}
    end
  end

  @spec resolve_intent(map()) :: {:ok, PromptResolveIntent.t()} | {:error, term()}
  def resolve_intent(attrs) when is_map(attrs) do
    required = [
      :tenant_ref,
      :authority_ref,
      :installation_ref,
      :idempotency_key,
      :trace_ref,
      :prompt_id,
      :ab_assignment_key,
      :resolution_policy
    ]

    with :ok <- reject_raw_payload(attrs),
         :ok <- required_strings(attrs, required),
         {:ok, requested_revision} <- positive_integer(attrs, :requested_revision) do
      {:ok,
       %PromptResolveIntent{
         tenant_ref: fetch!(attrs, :tenant_ref),
         authority_ref: fetch!(attrs, :authority_ref),
         installation_ref: fetch!(attrs, :installation_ref),
         idempotency_key: fetch!(attrs, :idempotency_key),
         trace_ref: fetch!(attrs, :trace_ref),
         prompt_id: fetch!(attrs, :prompt_id),
         requested_revision: requested_revision,
         ab_assignment_key: fetch!(attrs, :ab_assignment_key),
         resolution_policy: fetch!(attrs, :resolution_policy)
       }}
    end
  end

  @spec resolve_decision(map()) :: {:ok, PromptResolveDecision.t()} | {:error, term()}
  def resolve_decision(attrs) when is_map(attrs) do
    with {:ok, prompt_ref} <- attrs |> fetch(:prompt_ref) |> artifact_ref(),
         {:ok, decision_class} <- resolve_decision_class(fetch(attrs, :decision_class)),
         :ok <- required_strings(attrs, [:trace_ref]) do
      {:ok,
       %PromptResolveDecision{
         prompt_ref: prompt_ref,
         decision_class: decision_class,
         trace_ref: fetch!(attrs, :trace_ref)
       }}
    end
  end

  @spec author(Store.t(), map(), term()) ::
          {:ok, Store.t(), PromptArtifactRef.t()} | {:error, term()}
  def author(%Store{} = store, attrs, prompt_content) when is_map(attrs) do
    with :ok <-
           required_strings(attrs, [
             :tenant_ref,
             :installation_ref,
             :prompt_id,
             :redaction_policy_ref,
             :decision_evidence_ref
           ]),
         {:ok, level} <- redaction_level(fetch(attrs, :redaction_level, :redacted_excerpt_only)),
         revision = next_revision(store, fetch!(attrs, :prompt_id)),
         {:ok, lineage} <- lineage_ref(lineage_attrs(attrs, revision, nil, :author)),
         {:ok, ref} <- artifact_ref(artifact_attrs(attrs, revision, lineage, prompt_content)) do
      entry = %{
        ref: ref,
        lineage: lineage,
        redaction_level: level,
        redacted_excerpt: bounded_excerpt(prompt_content)
      }

      {:ok, put_revision(store, ref.prompt_id, revision, entry), ref}
    end
  end

  @spec rollback(Store.t(), map()) :: {:ok, Store.t(), PromptArtifactRef.t()} | {:error, term()}
  def rollback(%Store{} = store, attrs) when is_map(attrs) do
    with :ok <-
           required_strings(attrs, [
             :tenant_ref,
             :installation_ref,
             :prompt_id,
             :decision_evidence_ref
           ]),
         {:ok, target_revision} <- positive_integer(attrs, :target_revision),
         {:ok, target} <- fetch_revision(store, fetch!(attrs, :prompt_id), target_revision),
         :ok <- same_scope?(target.ref, attrs),
         revision = next_revision(store, target.ref.prompt_id),
         {:ok, lineage} <- lineage_ref(lineage_attrs(attrs, revision, target_revision, :rollback)),
         {:ok, ref} <-
           artifact_ref(
             %{target.ref | revision: revision, lineage_ref: lineage.lineage_ref}
             |> Map.from_struct()
           ) do
      entry = %{target | ref: ref, lineage: lineage}
      {:ok, put_revision(store, ref.prompt_id, revision, entry), ref}
    end
  end

  @spec assign_ab(Store.t(), map()) :: {:ok, PromptArtifactRef.t()} | {:error, term()}
  def assign_ab(%Store{} = store, attrs) when is_map(attrs) do
    with :ok <-
           required_strings(attrs, [
             :prompt_id,
             :tenant_ref,
             :installation_ref,
             :ab_assignment_key
           ]),
         variants when is_list(variants) and variants != [] <- fetch(attrs, :variant_revisions),
         {:ok, revision} <- choose_variant(attrs, variants) do
      case fetch_revision(store, fetch!(attrs, :prompt_id), revision) do
        {:ok, entry} -> same_scope?(entry.ref, attrs) |> then_ok(entry.ref)
        error -> error
      end
    else
      _other -> {:error, :invalid_ab_assignment}
    end
  end

  @spec view(Store.t(), map()) :: {:ok, map()} | {:error, term()}
  def view(%Store{} = store, attrs), do: project(store, attrs)

  @spec project(Store.t(), map()) :: {:ok, map()} | {:error, term()}
  def project(%Store{} = store, attrs) when is_map(attrs) do
    with {:ok, entry} <-
           fetch_revision(store, fetch!(attrs, :prompt_id), fetch!(attrs, :revision)),
         :ok <- same_scope?(entry.ref, attrs) do
      {:ok,
       %{
         prompt_ref: entry.ref,
         lineage_ref: entry.lineage.lineage_ref,
         content_hash: entry.ref.content_hash,
         redaction_policy_ref: entry.ref.redaction_policy_ref,
         redacted_excerpt: entry.redacted_excerpt
       }}
    end
  end

  @spec redact(Store.t(), map()) :: {:ok, map()} | {:error, term()}
  def redact(%Store{} = store, attrs) when is_map(attrs) do
    with {:ok, projection} <- project(store, attrs) do
      {:ok, %{projection | redacted_excerpt: nil}}
    end
  end

  defp put_revision(%Store{} = store, prompt_id, revision, entry) do
    prompt_revisions = store.prompts |> Map.get(prompt_id, %{}) |> Map.put(revision, entry)
    %Store{store | prompts: Map.put(store.prompts, prompt_id, prompt_revisions)}
  end

  defp fetch_revision(%Store{} = store, prompt_id, revision) do
    case get_in(store.prompts, [prompt_id, revision]) do
      nil -> {:error, :prompt_revision_missing}
      entry -> {:ok, entry}
    end
  end

  defp next_revision(%Store{prompts: prompts}, prompt_id) do
    prompts
    |> Map.get(prompt_id, %{})
    |> Map.keys()
    |> Enum.max(fn -> 0 end)
    |> Kernel.+(1)
  end

  defp artifact_attrs(attrs, revision, lineage, prompt_content) do
    %{
      prompt_id: fetch!(attrs, :prompt_id),
      revision: revision,
      tenant_ref: fetch!(attrs, :tenant_ref),
      installation_ref: fetch!(attrs, :installation_ref),
      content_hash: content_hash(prompt_content),
      redaction_policy_ref: fetch!(attrs, :redaction_policy_ref),
      lineage_ref: lineage.lineage_ref
    }
  end

  defp lineage_attrs(attrs, revision, parent_revision, reason) do
    %{
      lineage_ref: "prompt-lineage://#{fetch!(attrs, :prompt_id)}/#{revision}",
      prompt_id: fetch!(attrs, :prompt_id),
      revision: revision,
      parent_revision: parent_revision,
      derivation_reason: reason,
      decision_evidence_ref: fetch!(attrs, :decision_evidence_ref)
    }
  end

  defp choose_variant(attrs, variants) do
    seed =
      fetch!(attrs, :tenant_ref) <>
        ":" <> fetch!(attrs, :installation_ref) <> ":" <> fetch!(attrs, :ab_assignment_key)

    index = :crypto.hash(:sha256, seed) |> :binary.first() |> rem(length(variants))
    {:ok, Enum.at(variants, index)}
  end

  defp content_hash(value), do: "sha256:" <> sha256(canonical_encode(value))

  defp canonical_encode(value) when is_map(value) do
    value
    |> Enum.sort_by(fn {key, _value} -> to_string(key) end)
    |> Enum.map(fn {key, inner} -> [to_string(key), ":", canonical_encode(inner), ";"] end)
    |> IO.iodata_to_binary()
  end

  defp canonical_encode(value) when is_list(value) do
    value |> Enum.map(&canonical_encode/1) |> Enum.intersperse(",") |> IO.iodata_to_binary()
  end

  defp canonical_encode(value) when is_binary(value), do: value
  defp canonical_encode(value) when is_atom(value), do: Atom.to_string(value)
  defp canonical_encode(value), do: inspect(value)

  defp sha256(content), do: :crypto.hash(:sha256, content) |> Base.encode16(case: :lower)

  defp bounded_excerpt(value) do
    value
    |> canonical_encode()
    |> binary_part(0, min(byte_size(canonical_encode(value)), 120))
  end

  defp same_scope?(%PromptArtifactRef{} = ref, attrs) do
    if ref.tenant_ref == fetch(attrs, :tenant_ref) and
         ref.installation_ref == fetch(attrs, :installation_ref) do
      :ok
    else
      {:error, :cross_tenant_prompt_reuse}
    end
  end

  defp then_ok(:ok, value), do: {:ok, value}
  defp then_ok(error, _value), do: error

  defp reject_raw_payload(attrs) do
    case Enum.find(@raw_payload_keys, &Map.has_key?(attrs, &1)) do
      nil -> :ok
      key -> {:error, {:raw_prompt_body_forbidden, key}}
    end
  end

  defp required_strings(attrs, fields) do
    case Enum.find(fields, &(not present_string?(fetch(attrs, &1)))) do
      nil -> :ok
      field -> {:error, {:missing_prompt_ref, field}}
    end
  end

  defp positive_integer(attrs, field) do
    case fetch(attrs, field) do
      value when is_integer(value) and value > 0 -> {:ok, value}
      _value -> {:error, {:invalid_prompt_field, field}}
    end
  end

  defp derivation_reason(reason) when reason in @derivation_reasons, do: {:ok, reason}
  defp derivation_reason(_reason), do: {:error, :unknown_prompt_derivation_reason}

  defp resolve_decision_class(decision) when decision in @resolve_decisions, do: {:ok, decision}
  defp resolve_decision_class(_decision), do: {:error, :unknown_prompt_resolve_decision}

  defp redaction_level(level) when level in @redaction_levels, do: {:ok, level}
  defp redaction_level(_level), do: {:error, :unknown_prompt_redaction_level}

  defp present_string?(value) when is_binary(value), do: String.trim(value) != ""
  defp present_string?(_value), do: false

  defp fetch!(attrs, field), do: fetch(attrs, field)
  defp fetch(attrs, field), do: fetch(attrs, field, nil)

  defp fetch(attrs, field, default),
    do: Map.get(attrs, field) || Map.get(attrs, Atom.to_string(field)) || default
end
