defmodule OuterBrain.ContextABI.Failure do
  @moduledoc """
  Owner-local, safe failure shape for Context ABI and adjacent AI execution seams.
  """

  alias GroundPlane.Boundary.Codec

  @owners [
    :outer_brain,
    :citadel,
    :mezzanine,
    :jido_integration,
    :app_kit,
    :aitrace,
    :trinity,
    :gepa,
    :stack_lab
  ]
  @families [
    :context,
    :authority,
    :router,
    :model_execution,
    :eval,
    :memory,
    :optimization,
    :promotion,
    :evidence
  ]
  @family_prefixes [
    {"outer_brain.context.", :context},
    {"mezzanine.packet_admission.", :context},
    {"citadel.authority.", :authority},
    {"citadel.context_authority.", :authority},
    {"trinity.route.", :router},
    {"mezzanine.route.", :router},
    {"mezzanine.ai_execution.", :model_execution},
    {"jido_integration.model_invocation.", :model_execution},
    {"jido_integration.inference.", :model_execution},
    {"outer_brain.eval.", :eval},
    {"mezzanine.eval.", :eval},
    {"app_kit.eval.", :eval},
    {"outer_brain.memory.", :memory},
    {"mezzanine.memory.", :memory},
    {"gepa.optimization.", :optimization},
    {"mezzanine.optimization.", :optimization},
    {"citadel.promotion.", :promotion},
    {"mezzanine.promotion.", :promotion},
    {"aitrace.evidence.", :evidence},
    {"aitrace.replay.", :evidence},
    {"stack_lab.proof.", :evidence}
  ]
  @safe_summaries %{
    context: %{
      product: "Required context could not be assembled safely.",
      operator:
        "Context assembly failed. Review packet refs, trust class, redaction, and tenant evidence.",
      action: :fix_context_refs
    },
    authority: %{
      product: "The requested action was not authorized.",
      operator:
        "Authority evaluation failed or expired. Review Citadel grant, tenant, model, and route policy refs.",
      action: :deny_or_refresh_authority
    },
    router: %{
      product: "No governed route is currently available.",
      operator:
        "Router selection failed. Review route policy, allowed model profiles, fallback plan, and TRINITY refs.",
      action: :review_route_policy
    },
    model_execution: %{
      product: "The model request could not be completed safely.",
      operator:
        "Model invocation failed. Review credential lease, provider/runtime, timeout, and receipt refs.",
      action: :retry_or_select_fallback_runtime
    },
    eval: %{
      product: "Evaluation did not approve this result.",
      operator:
        "Eval gate failed or lacked evidence. Review suite, case, oracle, and verdict refs.",
      action: :review_eval_evidence
    },
    memory: %{
      product: "Memory could not be used or promoted safely.",
      operator:
        "Memory gate failed. Review candidate, promotion, tenant, staleness, and redaction refs.",
      action: :review_memory_gate
    },
    optimization: %{
      product: "Optimization could not produce a promotable candidate.",
      operator:
        "Optimization failed. Review candidate lineage, objective score, eval, promotion, and rollback refs.",
      action: :review_optimization_receipts
    },
    promotion: %{
      product: "The proposed update was not promoted.",
      operator:
        "Promotion or rollback gate failed. Review Citadel decision, eval verdict, and operator evidence.",
      action: :deny_or_review_promotion
    },
    evidence: %{
      product: "Required proof evidence is incomplete.",
      operator:
        "Evidence failed. Review trace, replay, receipt hash, scanner, proof-matrix, and docs refs.",
      action: :repair_evidence_chain
    }
  }

  @enforce_keys [:owner, :reason_code, :safe_message]
  defstruct [
    :owner,
    :reason_code,
    :safe_message,
    retryable?: false,
    trace_ref: nil,
    evidence_refs: []
  ]

  @type owner ::
          :outer_brain
          | :citadel
          | :mezzanine
          | :jido_integration
          | :app_kit
          | :aitrace
          | :trinity
          | :gepa
          | :stack_lab

  @type t :: %__MODULE__{
          owner: owner(),
          reason_code: String.t(),
          safe_message: String.t(),
          retryable?: boolean(),
          trace_ref: String.t() | nil,
          evidence_refs: [String.t()]
        }

  @spec owners() :: [owner()]
  def owners, do: @owners

  @spec families() :: [atom()]
  def families, do: @families

  @spec new(map() | keyword() | t()) :: {:ok, t()} | {:error, term()}
  def new(%__MODULE__{} = failure), do: {:ok, failure}
  def new(attrs) when is_list(attrs), do: attrs |> Map.new() |> new()

  def new(attrs) when is_map(attrs) do
    with {:ok, owner} <- owner(value(attrs, :owner)),
         {:ok, reason_code} <- string(attrs, :reason_code),
         :ok <- reason_code_owner(owner, reason_code),
         :ok <- reason_code_version(reason_code),
         {:ok, safe_message} <- string(attrs, :safe_message),
         {:ok, evidence_refs} <- optional_string_list(attrs, :evidence_refs) do
      {:ok,
       %__MODULE__{
         owner: owner,
         reason_code: reason_code,
         safe_message: safe_message,
         retryable?: value(attrs, :retryable?) == true,
         trace_ref: optional_string(attrs, :trace_ref),
         evidence_refs: evidence_refs
       }}
    end
  end

  def new(_attrs), do: {:error, :invalid_failure}

  @spec new!(map() | keyword() | t()) :: t()
  def new!(attrs) do
    case new(attrs) do
      {:ok, failure} -> failure
      {:error, reason} -> raise ArgumentError, "invalid Context ABI failure: #{inspect(reason)}"
    end
  end

  @spec family_for(t() | String.t()) :: {:ok, atom()} | {:error, :unknown_failure_family}
  def family_for(%__MODULE__{reason_code: reason_code}), do: family_for(reason_code)

  def family_for(reason_code) when is_binary(reason_code) do
    Enum.find_value(@family_prefixes, fn {prefix, family} ->
      if String.starts_with?(reason_code, prefix), do: family
    end)
    |> case do
      nil -> infer_family(reason_code)
      family -> {:ok, family}
    end
  end

  def family_for(_reason_code), do: {:error, :unknown_failure_family}

  @spec summary(t()) :: {:ok, map()} | {:error, term()}
  def summary(%__MODULE__{} = failure) do
    with {:ok, family} <- family_for(failure) do
      template = Map.fetch!(@safe_summaries, family)

      {:ok,
       %{
         failure_ref: failure_ref(failure, family),
         failure_family: family,
         owner: failure.owner,
         reason_code: failure.reason_code,
         safe_message: failure.safe_message,
         product_summary: template.product,
         operator_summary: template.operator,
         safe_action: template.action,
         retryable?: failure.retryable?,
         trace_ref: failure.trace_ref,
         evidence_refs: failure.evidence_refs
       }}
    end
  end

  @spec summary!(t()) :: map()
  def summary!(%__MODULE__{} = failure) do
    case summary(failure) do
      {:ok, summary} -> summary
      {:error, reason} -> raise ArgumentError, "cannot summarize failure: #{inspect(reason)}"
    end
  end

  defp owner(owner) when owner in @owners, do: {:ok, owner}

  defp owner(owner) when is_binary(owner) do
    Enum.find(@owners, &(Atom.to_string(&1) == owner))
    |> case do
      nil -> {:error, :invalid_failure_owner}
      found -> {:ok, found}
    end
  end

  defp owner(_owner), do: {:error, :invalid_failure_owner}

  defp infer_family(reason_code) do
    case Enum.find(@family_prefixes, fn {prefix, _family} ->
           String.starts_with?(reason_code, prefix)
         end) do
      {_prefix, family} -> {:ok, family}
      nil -> infer_family_from_fragment(reason_code)
    end
  end

  defp infer_family_from_fragment(reason_code) do
    [
      {".model_", :model_execution},
      {".inference.", :model_execution},
      {".rollback.", :promotion}
    ]
    |> Enum.find(fn {fragment, _family} -> String.contains?(reason_code, fragment) end)
    |> case do
      {_fragment, family} -> {:ok, family}
      nil -> {:error, :unknown_failure_family}
    end
  end

  defp failure_ref(failure, family) do
    digest =
      %{
        owner: Atom.to_string(failure.owner),
        reason_code: failure.reason_code,
        family: Atom.to_string(family),
        trace_ref: failure.trace_ref || "",
        evidence_refs: failure.evidence_refs
      }
      |> Codec.digest()
      |> String.replace_prefix("sha256:", "")

    "failure://#{Atom.to_string(failure.owner)}/#{digest}"
  end

  defp reason_code_owner(owner, reason_code) do
    prefix = Atom.to_string(owner) <> "."

    if String.starts_with?(reason_code, prefix) do
      :ok
    else
      {:error, :reason_code_owner_mismatch}
    end
  end

  defp reason_code_version(reason_code) do
    if String.match?(reason_code, ~r/\.v[0-9]+$/) do
      :ok
    else
      {:error, :unversioned_reason_code}
    end
  end

  defp string(attrs, field) do
    case value(attrs, field) do
      candidate when is_binary(candidate) and candidate != "" -> {:ok, candidate}
      _other -> {:error, {:missing_failure_field, field}}
    end
  end

  defp optional_string(attrs, field) do
    case value(attrs, field) do
      candidate when is_binary(candidate) and candidate != "" -> candidate
      _other -> nil
    end
  end

  defp optional_string_list(attrs, field) do
    case value(attrs, field) do
      nil -> {:ok, []}
      values when is_list(values) -> validate_string_list(values, field)
      _other -> {:error, {:invalid_failure_field, field}}
    end
  end

  defp validate_string_list(values, field) do
    if Enum.all?(values, &(is_binary(&1) and &1 != "")) do
      {:ok, values}
    else
      {:error, {:invalid_failure_field, field}}
    end
  end

  defp value(attrs, field), do: Map.get(attrs, field) || Map.get(attrs, Atom.to_string(field))
end
