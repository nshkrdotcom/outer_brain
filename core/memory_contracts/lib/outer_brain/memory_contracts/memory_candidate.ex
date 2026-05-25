defmodule OuterBrain.MemoryContracts.MemoryCandidate do
  @moduledoc """
  Ref-only memory candidate contract for governed promotion.

  A candidate is not production memory. It records the memory/evidence refs and
  eval/Citadel facts required before a promoted memory ref can participate in a
  production Context ABI packet.
  """

  alias OuterBrain.MemoryContracts.{MemoryEvidenceRef, MemoryRef, Validator, Vocabulary}

  @enforce_keys [
    :candidate_ref,
    :tenant_ref,
    :memory_ref,
    :evidence_ref,
    :eval_evidence_refs,
    :authority_ref,
    :trace_ref,
    :redaction_policy_ref,
    :status
  ]
  defstruct [:promotion_ref, :rollback_ref | @enforce_keys]

  @type status :: :candidate | :promoted | :rolled_back

  @type t :: %__MODULE__{
          candidate_ref: String.t(),
          tenant_ref: String.t(),
          memory_ref: MemoryRef.t(),
          evidence_ref: MemoryEvidenceRef.t(),
          eval_evidence_refs: [String.t()],
          authority_ref: String.t(),
          trace_ref: String.t(),
          redaction_policy_ref: String.t(),
          status: status(),
          promotion_ref: String.t() | nil,
          rollback_ref: String.t() | nil
        }

  @spec new(map() | t()) :: {:ok, t()} | {:error, term()}
  def new(%__MODULE__{} = candidate), do: {:ok, candidate}

  def new(attrs) when is_map(attrs) do
    with :ok <- Validator.reject_raw_payload(attrs),
         {:ok, candidate_ref} <- required_string(attrs, :candidate_ref),
         {:ok, tenant_ref} <- required_string(attrs, :tenant_ref),
         {:ok, memory_ref} <- attrs |> Validator.fetch_value(:memory_ref) |> MemoryRef.new(),
         {:ok, evidence_ref} <-
           attrs |> Validator.fetch_value(:evidence_ref) |> MemoryEvidenceRef.new(),
         {:ok, eval_evidence_refs} <- required_strings(attrs, :eval_evidence_refs),
         {:ok, authority_ref} <- required_string(attrs, :authority_ref),
         {:ok, trace_ref} <- required_string(attrs, :trace_ref),
         {:ok, redaction_policy_ref} <- required_string(attrs, :redaction_policy_ref),
         {:ok, status} <- candidate_status(attrs),
         :ok <- status_refs_present(attrs, status) do
      {:ok,
       %__MODULE__{
         candidate_ref: candidate_ref,
         tenant_ref: tenant_ref,
         memory_ref: memory_ref,
         evidence_ref: evidence_ref,
         eval_evidence_refs: eval_evidence_refs,
         authority_ref: authority_ref,
         trace_ref: trace_ref,
         redaction_policy_ref: redaction_policy_ref,
         status: status,
         promotion_ref: optional_string(attrs, :promotion_ref),
         rollback_ref: optional_string(attrs, :rollback_ref)
       }}
    end
  end

  def new(_attrs), do: {:error, :invalid_memory_candidate}

  defp candidate_status(attrs) do
    status = Validator.fetch_value(attrs, :status) || :candidate

    if status in Vocabulary.memory_candidate_statuses() do
      {:ok, status}
    else
      {:error, {:invalid_candidate_status, status}}
    end
  end

  defp status_refs_present(attrs, :promoted) do
    case required_string(attrs, :promotion_ref) do
      {:ok, _ref} -> :ok
      {:error, _reason} -> {:error, {:missing_candidate_ref, :promotion_ref}}
    end
  end

  defp status_refs_present(attrs, :rolled_back) do
    case required_string(attrs, :rollback_ref) do
      {:ok, _ref} -> :ok
      {:error, _reason} -> {:error, {:missing_candidate_ref, :rollback_ref}}
    end
  end

  defp status_refs_present(_attrs, :candidate), do: :ok

  defp required_string(attrs, field) do
    case Validator.required_string(attrs, field) do
      {:ok, value} -> {:ok, value}
      {:error, _reason} -> {:error, {:missing_candidate_ref, field}}
    end
  end

  defp optional_string(attrs, field), do: Validator.optional_string(attrs, field)

  defp required_strings(attrs, field) do
    case Validator.fetch_value(attrs, field) do
      values when is_list(values) and values != [] ->
        if Enum.all?(values, &(is_binary(&1) and String.trim(&1) != "")) do
          {:ok, Enum.uniq(values)}
        else
          {:error, {:missing_candidate_ref, field}}
        end

      _other ->
        {:error, {:missing_candidate_ref, field}}
    end
  end
end
