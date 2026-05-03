defmodule OuterBrain.Contracts.ReflectionResult do
  @moduledoc """
  Strict tagged result returned by the M2 `Reflect` activity.

  Exactly one variant payload is allowed. The workflow-visible payload is refs,
  bands, and diagnostics only; raw model output and prompts stay claim-checked
  outside workflow history.
  """

  @variants [:action_request, :final_answer, :clarification_request, :semantic_failure]
  @variant_by_string Map.new(@variants, &{Atom.to_string(&1), &1})
  @bands [:low, :medium, :high]
  @band_by_string Map.new(@bands, &{Atom.to_string(&1), &1})
  @variant_fields %{
    action_request: :action_request_ref,
    final_answer: :final_answer_ref,
    clarification_request: :clarification_request_ref,
    semantic_failure: :semantic_failure_ref
  }
  @fields [
    :result_ref,
    :variant,
    :action_request_ref,
    :final_answer_ref,
    :clarification_request_ref,
    :semantic_failure_ref,
    :risk_band,
    :confidence_band,
    :trace_id,
    diagnostics: []
  ]

  defstruct @fields

  def new(%__MODULE__{} = result), do: {:ok, result}

  def new(attrs) when is_map(attrs) do
    with :ok <- reject_forbidden(attrs),
         {:ok, result_ref} <- required_ref(attrs, :result_ref),
         {:ok, trace_id} <- required_ref(attrs, :trace_id),
         {:ok, variant} <- variant(attrs),
         :ok <- exactly_one_variant(attrs, variant),
         {:ok, risk_band} <- band(attrs, :risk_band),
         {:ok, confidence_band} <- band(attrs, :confidence_band),
         diagnostics <- get(attrs, :diagnostics, []),
         true <- is_list(diagnostics) do
      {:ok,
       struct!(
         __MODULE__,
         %{
           result_ref: result_ref,
           variant: variant,
           action_request_ref: get(attrs, :action_request_ref),
           final_answer_ref: get(attrs, :final_answer_ref),
           clarification_request_ref: get(attrs, :clarification_request_ref),
           semantic_failure_ref: get(attrs, :semantic_failure_ref),
           risk_band: risk_band,
           confidence_band: confidence_band,
           trace_id: trace_id,
           diagnostics: diagnostics
         }
       )}
    else
      _ -> {:error, :invalid_reflection_result}
    end
  end

  def new(_attrs), do: {:error, :invalid_reflection_result}
  def new!(attrs), do: bang(new(attrs))

  def workflow_history_payload(%__MODULE__{} = result) do
    result
    |> Map.from_struct()
    |> Map.take([
      :result_ref,
      :variant,
      variant_field(result.variant),
      :risk_band,
      :confidence_band,
      :trace_id
    ])
  end

  def to_payload(%__MODULE__{} = result) do
    result
    |> Map.from_struct()
    |> Enum.into(%{}, fn {key, value} -> {Atom.to_string(key), dump_value(value)} end)
    |> drop_nil_values()
  end

  defp variant(attrs) do
    enum_value(get(attrs, :variant), @variants, @variant_by_string, :invalid_variant)
  end

  defp exactly_one_variant(attrs, variant) do
    present =
      @variant_fields
      |> Map.values()
      |> Enum.filter(&(get(attrs, &1) not in [nil, ""]))

    expected = variant_field(variant)

    if present == [expected] and safe_ref?(get(attrs, expected)),
      do: :ok,
      else: {:error, :invalid_variant_payload}
  end

  defp variant_field(variant), do: Map.fetch!(@variant_fields, variant)

  defp band(attrs, key) do
    enum_value(get(attrs, key), @bands, @band_by_string, :invalid_band)
  end

  defp enum_value(value, allowed, _by_string, error) when is_atom(value) do
    if value in allowed, do: {:ok, value}, else: {:error, error}
  end

  defp enum_value(value, _allowed, by_string, _error) when is_binary(value),
    do: Map.fetch(by_string, value)

  defp enum_value(_value, _allowed, _by_string, error), do: {:error, error}

  defp required_ref(attrs, key) do
    case get(attrs, key) do
      value when is_binary(value) ->
        if safe_ref?(value), do: {:ok, value}, else: {:error, key}

      _other ->
        {:error, key}
    end
  end

  defp reject_forbidden(attrs) do
    if forbidden?(attrs), do: {:error, :forbidden_raw_payload}, else: :ok
  end

  defp forbidden?(%{} = attrs) do
    Enum.any?(attrs, fn {key, value} -> forbidden_key?(key) or forbidden?(value) end)
  end

  defp forbidden?(values) when is_list(values), do: Enum.any?(values, &forbidden?/1)
  defp forbidden?(value) when is_binary(value), do: String.starts_with?(value, ["/", "~/"])
  defp forbidden?(_value), do: false

  defp forbidden_key?(key) when is_atom(key), do: forbidden_key?(Atom.to_string(key))

  defp forbidden_key?(key) when is_binary(key) do
    key in [
      "prompt",
      "raw_prompt",
      "raw_provider_payload",
      "raw_provider_body",
      "provider_payload",
      "tool_call",
      "workspace_path"
    ]
  end

  defp forbidden_key?(_key), do: false

  defp get(attrs, key, default \\ nil) do
    Map.get(attrs, key, Map.get(attrs, Atom.to_string(key), default))
  end

  defp safe_ref?(value),
    do:
      is_binary(value) and String.trim(value) != "" and
        not String.starts_with?(value, ["/", "~/"])

  defp dump_value(value) when is_atom(value), do: Atom.to_string(value)
  defp dump_value(values) when is_list(values), do: Enum.map(values, &dump_value/1)
  defp dump_value(value), do: value
  defp drop_nil_values(map), do: Map.reject(map, fn {_key, value} -> is_nil(value) end)
  defp bang({:ok, value}), do: value
  defp bang({:error, reason}), do: raise(ArgumentError, Atom.to_string(reason))
end

defmodule OuterBrain.Contracts.CandidateFact do
  @moduledoc """
  Phase 5 semantic fact proposal.

  Candidate facts are proposals, not private-memory truth. Phase 7 owns
  acceptance through Mezzanine PrivateWriter and m7a proof.
  """

  @fact_kinds [:tool_observation, :runtime_summary, :user_preference, :project_fact]
  @fact_kinds_by_string Map.new(@fact_kinds, &{Atom.to_string(&1), &1})
  @confidence_classes [:observed, :inferred, :reported]
  @confidence_classes_by_string Map.new(@confidence_classes, &{Atom.to_string(&1), &1})
  @redaction_classes [:claim_checked, :public_summary, :redacted]
  @redaction_classes_by_string Map.new(@redaction_classes, &{Atom.to_string(&1), &1})
  @bands [:low, :medium, :high]
  @bands_by_string Map.new(@bands, &{Atom.to_string(&1), &1})
  @fields [
    :candidate_fact_ref,
    :fact_kind,
    :confidence_class,
    :confidence_band,
    :risk_band,
    :source_observation_ref,
    :evidence_ref,
    :redaction_ref,
    :redaction_class,
    :claim_check_refs,
    :proposed_by,
    :trace_id
  ]

  defstruct @fields

  def new(%__MODULE__{} = fact), do: {:ok, fact}

  def new(attrs) when is_map(attrs) do
    with :ok <- reject_forbidden(attrs),
         {:ok, candidate_fact_ref} <- required_ref(attrs, :candidate_fact_ref),
         {:ok, source_observation_ref} <- required_ref(attrs, :source_observation_ref),
         {:ok, evidence_ref} <- required_ref(attrs, :evidence_ref),
         {:ok, redaction_ref} <- required_ref(attrs, :redaction_ref),
         {:ok, proposed_by} <- required_ref(attrs, :proposed_by),
         {:ok, trace_id} <- required_ref(attrs, :trace_id),
         {:ok, fact_kind} <- atom_value(attrs, :fact_kind, @fact_kinds, @fact_kinds_by_string),
         {:ok, confidence_class} <-
           atom_value(
             attrs,
             :confidence_class,
             @confidence_classes,
             @confidence_classes_by_string
           ),
         {:ok, confidence_band} <-
           atom_value(attrs, :confidence_band, @bands, @bands_by_string),
         {:ok, risk_band} <- atom_value(attrs, :risk_band, @bands, @bands_by_string),
         {:ok, redaction_class} <-
           atom_value(attrs, :redaction_class, @redaction_classes, @redaction_classes_by_string),
         claim_check_refs <- get(attrs, :claim_check_refs, []),
         true <- is_list(claim_check_refs) and Enum.all?(claim_check_refs, &safe_ref?/1) do
      {:ok,
       %__MODULE__{
         candidate_fact_ref: candidate_fact_ref,
         fact_kind: fact_kind,
         confidence_class: confidence_class,
         confidence_band: confidence_band,
         risk_band: risk_band,
         source_observation_ref: source_observation_ref,
         evidence_ref: evidence_ref,
         redaction_ref: redaction_ref,
         redaction_class: redaction_class,
         claim_check_refs: claim_check_refs,
         proposed_by: proposed_by,
         trace_id: trace_id
       }}
    else
      _ -> {:error, :invalid_candidate_fact}
    end
  end

  def new(_attrs), do: {:error, :invalid_candidate_fact}
  def new!(attrs), do: bang(new(attrs))

  def workflow_history_payload(%__MODULE__{} = fact) do
    Map.take(fact, [
      :candidate_fact_ref,
      :fact_kind,
      :confidence_band,
      :risk_band,
      :source_observation_ref,
      :evidence_ref,
      :redaction_ref,
      :claim_check_refs,
      :trace_id
    ])
  end

  def to_payload(%__MODULE__{} = fact) do
    fact
    |> Map.from_struct()
    |> Enum.into(%{}, fn {key, value} -> {Atom.to_string(key), dump_value(value)} end)
  end

  defp atom_value(attrs, key, allowed, by_string) do
    case get(attrs, key) do
      value when is_atom(value) ->
        if value in allowed, do: {:ok, value}, else: {:error, key}

      value when is_binary(value) ->
        atom_from_string(value, by_string)

      _other ->
        {:error, key}
    end
  end

  defp atom_from_string(value, by_string), do: Map.fetch(by_string, value)

  defp required_ref(attrs, key) do
    case get(attrs, key) do
      value when is_binary(value) ->
        if safe_ref?(value), do: {:ok, value}, else: {:error, key}

      _other ->
        {:error, key}
    end
  end

  defp reject_forbidden(attrs) do
    if forbidden?(attrs), do: {:error, :forbidden_raw_payload}, else: :ok
  end

  defp forbidden?(%{} = attrs) do
    Enum.any?(attrs, fn {key, value} -> forbidden_key?(key) or forbidden?(value) end)
  end

  defp forbidden?(values) when is_list(values), do: Enum.any?(values, &forbidden?/1)
  defp forbidden?(value) when is_binary(value), do: String.starts_with?(value, ["/", "~/"])
  defp forbidden?(_value), do: false

  defp forbidden_key?(key) when is_atom(key), do: forbidden_key?(Atom.to_string(key))

  defp forbidden_key?(key) when is_binary(key) do
    key in [
      "prompt",
      "raw_prompt",
      "raw_provider_payload",
      "raw_provider_body",
      "provider_payload",
      "tool_output",
      "workspace_path"
    ]
  end

  defp forbidden_key?(_key), do: false

  defp get(attrs, key, default \\ nil) do
    Map.get(attrs, key, Map.get(attrs, Atom.to_string(key), default))
  end

  defp safe_ref?(value),
    do:
      is_binary(value) and String.trim(value) != "" and
        not String.starts_with?(value, ["/", "~/"])

  defp dump_value(value) when is_atom(value), do: Atom.to_string(value)
  defp dump_value(values) when is_list(values), do: Enum.map(values, &dump_value/1)
  defp dump_value(value), do: value
  defp bang({:ok, value}), do: value
  defp bang({:error, reason}), do: raise(ArgumentError, Atom.to_string(reason))
end

defmodule OuterBrain.Contracts.CandidateFactSet do
  @moduledoc """
  Phase 7 semantic extraction result for M2.

  A fact set groups candidate proposals and a bounded extraction receipt. It
  intentionally carries no private-memory commit fields; Mezzanine
  `PrivateWriter` is the only boundary that can turn proposals into truth.
  """

  alias OuterBrain.Contracts.CandidateFact

  @fields [
    :candidate_fact_set_ref,
    :candidate_facts,
    :fact_extraction_receipt_ref,
    :source_observation_refs,
    :proposed_by,
    :trace_id
  ]

  defstruct @fields

  def new(%__MODULE__{} = set), do: {:ok, set}

  def new(attrs) when is_map(attrs) do
    with :ok <- reject_forbidden(attrs),
         {:ok, candidate_fact_set_ref} <- required_ref(attrs, :candidate_fact_set_ref),
         {:ok, fact_extraction_receipt_ref} <- required_ref(attrs, :fact_extraction_receipt_ref),
         {:ok, proposed_by} <- required_ref(attrs, :proposed_by),
         {:ok, trace_id} <- required_ref(attrs, :trace_id),
         source_observation_refs <- get(attrs, :source_observation_refs, []),
         true <-
           is_list(source_observation_refs) and Enum.all?(source_observation_refs, &safe_ref?/1),
         {:ok, candidate_facts} <- candidate_facts(get(attrs, :candidate_facts, [])) do
      {:ok,
       %__MODULE__{
         candidate_fact_set_ref: candidate_fact_set_ref,
         candidate_facts: candidate_facts,
         fact_extraction_receipt_ref: fact_extraction_receipt_ref,
         source_observation_refs: source_observation_refs,
         proposed_by: proposed_by,
         trace_id: trace_id
       }}
    else
      _ -> {:error, :invalid_candidate_fact_set}
    end
  end

  def new(_attrs), do: {:error, :invalid_candidate_fact_set}
  def new!(attrs), do: bang(new(attrs))

  def workflow_history_payload(%__MODULE__{} = set) do
    %{
      candidate_fact_set_ref: set.candidate_fact_set_ref,
      candidate_fact_refs: Enum.map(set.candidate_facts, & &1.candidate_fact_ref),
      fact_extraction_receipt_ref: set.fact_extraction_receipt_ref,
      source_observation_refs: set.source_observation_refs,
      trace_id: set.trace_id
    }
  end

  def to_payload(%__MODULE__{} = set) do
    %{
      "candidate_fact_set_ref" => set.candidate_fact_set_ref,
      "candidate_facts" => Enum.map(set.candidate_facts, &CandidateFact.to_payload/1),
      "fact_extraction_receipt_ref" => set.fact_extraction_receipt_ref,
      "source_observation_refs" => set.source_observation_refs,
      "proposed_by" => set.proposed_by,
      "trace_id" => set.trace_id
    }
  end

  defp candidate_facts([_ | _] = facts) do
    Enum.reduce_while(facts, {:ok, []}, fn attrs, {:ok, acc} ->
      case CandidateFact.new(attrs) do
        {:ok, fact} -> {:cont, {:ok, [fact | acc]}}
        {:error, reason} -> {:halt, {:error, reason}}
      end
    end)
    |> case do
      {:ok, facts} -> {:ok, Enum.reverse(facts)}
      error -> error
    end
  end

  defp candidate_facts(_facts), do: {:error, :missing_candidate_facts}

  defp required_ref(attrs, key) do
    case get(attrs, key) do
      value when is_binary(value) ->
        if safe_ref?(value), do: {:ok, value}, else: {:error, key}

      _other ->
        {:error, key}
    end
  end

  defp reject_forbidden(attrs) do
    if forbidden?(attrs), do: {:error, :forbidden_raw_payload}, else: :ok
  end

  defp forbidden?(%{} = attrs) do
    Enum.any?(attrs, fn {key, value} -> forbidden_key?(key) or forbidden?(value) end)
  end

  defp forbidden?(values) when is_list(values), do: Enum.any?(values, &forbidden?/1)
  defp forbidden?(value) when is_binary(value), do: String.starts_with?(value, ["/", "~/"])
  defp forbidden?(_value), do: false

  defp forbidden_key?(key) when is_atom(key), do: forbidden_key?(Atom.to_string(key))

  defp forbidden_key?(key) when is_binary(key) do
    key in [
      "memory_commit_ref",
      "m7a_proof_ref",
      "prompt",
      "raw_prompt",
      "raw_provider_payload",
      "raw_provider_body",
      "provider_payload",
      "tool_output",
      "workspace_path"
    ]
  end

  defp forbidden_key?(_key), do: false

  defp get(attrs, key, default \\ nil) do
    Map.get(attrs, key, Map.get(attrs, Atom.to_string(key), default))
  end

  defp safe_ref?(value),
    do:
      is_binary(value) and String.trim(value) != "" and
        not String.starts_with?(value, ["/", "~/"])

  defp bang({:ok, value}), do: value
  defp bang({:error, reason}), do: raise(ArgumentError, Atom.to_string(reason))
end
