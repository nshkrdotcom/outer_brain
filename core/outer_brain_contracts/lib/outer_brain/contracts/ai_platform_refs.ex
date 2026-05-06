defmodule OuterBrain.Contracts.AIPlatformRefs do
  @moduledoc """
  Ref-only AI Platform contracts shared by lower integration owners.
  """

  @prompt_ref_fields [
    :prompt_id,
    :revision,
    :tenant_ref,
    :installation_ref,
    :content_hash,
    :redaction_policy_ref,
    :lineage_ref
  ]
  @lineage_ref_fields [
    :lineage_ref,
    :prompt_id,
    :revision,
    :derivation_reason,
    :decision_evidence_ref
  ]
  @guard_decision_ref_fields [
    :guard_decision_ref,
    :tenant_ref,
    :authority_ref,
    :installation_ref,
    :trace_ref,
    :detector_chain_ref,
    :decision_class,
    :redaction_posture
  ]
  @guard_chain_ref_fields [
    :guard_chain_ref,
    :tenant_ref,
    :installation_ref,
    :policy_revision_ref,
    :detector_refs,
    :redaction_posture_floor
  ]
  @raw_keys [
    :body,
    :raw_body,
    :prompt_body,
    :raw_prompt,
    :payload,
    :raw_payload,
    :guard_payload,
    :guard_violation_body,
    "body",
    "raw_body",
    "prompt_body",
    "raw_prompt",
    "payload",
    "raw_payload",
    "guard_payload",
    "guard_violation_body"
  ]
  @derivation_reasons [:author, :auto_promote, :rollback, :ab_split, :ab_collapse]
  @decision_classes [
    :allow,
    :allow_with_redaction,
    :block,
    :escalate,
    :deny_policy,
    :deny_detector_unavailable
  ]
  @redaction_postures [:pass, :partial, :excerpt_only, :no_export, :block]

  defmodule PromptArtifactRef do
    @moduledoc "Prompt artifact ref with no raw prompt body."
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

  defmodule GuardDecisionRef do
    @moduledoc "Guard decision ref with bounded decision posture."
    @enforce_keys [
      :guard_decision_ref,
      :tenant_ref,
      :authority_ref,
      :installation_ref,
      :trace_ref,
      :detector_chain_ref,
      :decision_class,
      :redaction_posture
    ]
    defstruct @enforce_keys

    @type t :: %__MODULE__{
            guard_decision_ref: String.t(),
            tenant_ref: String.t(),
            authority_ref: String.t(),
            installation_ref: String.t(),
            trace_ref: String.t(),
            detector_chain_ref: String.t(),
            decision_class: atom(),
            redaction_posture: atom()
          }
  end

  defmodule GuardChainRef do
    @moduledoc "Guard chain ref selected by policy."
    @enforce_keys [
      :guard_chain_ref,
      :tenant_ref,
      :installation_ref,
      :policy_revision_ref,
      :detector_refs,
      :redaction_posture_floor
    ]
    defstruct @enforce_keys

    @type t :: %__MODULE__{
            guard_chain_ref: String.t(),
            tenant_ref: String.t(),
            installation_ref: String.t(),
            policy_revision_ref: String.t(),
            detector_refs: [String.t()],
            redaction_posture_floor: atom()
          }
  end

  @spec prompt_artifact_ref(map()) :: {:ok, PromptArtifactRef.t()} | {:error, term()}
  def prompt_artifact_ref(attrs) when is_map(attrs) do
    with :ok <- reject_raw(attrs),
         :ok <- required(attrs, @prompt_ref_fields),
         {:ok, revision} <- positive_integer(attrs, :revision) do
      {:ok,
       %PromptArtifactRef{
         prompt_id: value!(attrs, :prompt_id),
         revision: revision,
         tenant_ref: value!(attrs, :tenant_ref),
         installation_ref: value!(attrs, :installation_ref),
         content_hash: value!(attrs, :content_hash),
         redaction_policy_ref: value!(attrs, :redaction_policy_ref),
         lineage_ref: value!(attrs, :lineage_ref)
       }}
    end
  end

  @spec prompt_lineage_ref(map()) :: {:ok, PromptLineageRef.t()} | {:error, term()}
  def prompt_lineage_ref(attrs) when is_map(attrs) do
    with :ok <- required(attrs, @lineage_ref_fields),
         {:ok, revision} <- positive_integer(attrs, :revision),
         {:ok, reason} <- member(attrs, :derivation_reason, @derivation_reasons) do
      {:ok,
       %PromptLineageRef{
         lineage_ref: value!(attrs, :lineage_ref),
         prompt_id: value!(attrs, :prompt_id),
         revision: revision,
         parent_revision: value(attrs, :parent_revision),
         derivation_reason: reason,
         decision_evidence_ref: value!(attrs, :decision_evidence_ref)
       }}
    end
  end

  @spec guard_decision_ref(map()) :: {:ok, GuardDecisionRef.t()} | {:error, term()}
  def guard_decision_ref(attrs) when is_map(attrs) do
    with :ok <- reject_raw(attrs),
         :ok <- required(attrs, @guard_decision_ref_fields),
         {:ok, decision_class} <- member(attrs, :decision_class, @decision_classes),
         {:ok, redaction_posture} <- member(attrs, :redaction_posture, @redaction_postures) do
      {:ok,
       %GuardDecisionRef{
         guard_decision_ref: value!(attrs, :guard_decision_ref),
         tenant_ref: value!(attrs, :tenant_ref),
         authority_ref: value!(attrs, :authority_ref),
         installation_ref: value!(attrs, :installation_ref),
         trace_ref: value!(attrs, :trace_ref),
         detector_chain_ref: value!(attrs, :detector_chain_ref),
         decision_class: decision_class,
         redaction_posture: redaction_posture
       }}
    end
  end

  @spec guard_chain_ref(map()) :: {:ok, GuardChainRef.t()} | {:error, term()}
  def guard_chain_ref(attrs) when is_map(attrs) do
    with :ok <- reject_raw(attrs),
         :ok <- required(attrs, @guard_chain_ref_fields),
         detector_refs when is_list(detector_refs) and detector_refs != [] <-
           value(attrs, :detector_refs),
         {:ok, posture} <- member(attrs, :redaction_posture_floor, @redaction_postures) do
      {:ok,
       %GuardChainRef{
         guard_chain_ref: value!(attrs, :guard_chain_ref),
         tenant_ref: value!(attrs, :tenant_ref),
         installation_ref: value!(attrs, :installation_ref),
         policy_revision_ref: value!(attrs, :policy_revision_ref),
         detector_refs: detector_refs,
         redaction_posture_floor: posture
       }}
    else
      _other -> {:error, :invalid_guard_chain_ref}
    end
  end

  defp reject_raw(attrs) do
    case Enum.find(@raw_keys, &Map.has_key?(attrs, &1)) do
      nil -> :ok
      key -> {:error, {:raw_ai_platform_ref_payload_forbidden, key}}
    end
  end

  defp required(attrs, fields) do
    case Enum.find(fields, &(not present?(value(attrs, &1)))) do
      nil -> :ok
      field -> {:error, {:missing_ai_platform_ref, field}}
    end
  end

  defp positive_integer(attrs, field) do
    case value(attrs, field) do
      integer when is_integer(integer) and integer > 0 -> {:ok, integer}
      _other -> {:error, {:invalid_ai_platform_ref, field}}
    end
  end

  defp member(attrs, field, allowed) do
    candidate = value(attrs, field)

    if candidate in allowed do
      {:ok, candidate}
    else
      {:error, {:invalid_ai_platform_ref, field}}
    end
  end

  defp present?(value) when is_binary(value), do: String.trim(value) != ""
  defp present?(value) when is_list(value), do: value != []
  defp present?(value), do: not is_nil(value)

  defp value!(attrs, field), do: value(attrs, field)
  defp value(attrs, field), do: Map.get(attrs, field) || Map.get(attrs, Atom.to_string(field))
end
