defmodule OuterBrain.EvalRunner do
  @moduledoc """
  Deterministic eval runner over bounded variant matrices.
  """

  alias Mezzanine.EvalEngine

  @max_variants 16
  @required_variant_fields [
    :prompt_revision,
    :model_ref,
    :policy_revision,
    :guard_chain_ref,
    :memory_profile_ref
  ]
  @raw_keys [
    :body,
    :raw_body,
    :payload,
    :raw_payload,
    :model_output,
    :provider_payload,
    "body",
    "raw_body",
    "payload",
    "raw_payload",
    "model_output",
    "provider_payload"
  ]

  @spec run(map(), [map()], keyword()) :: {:ok, map()} | {:error, term()}
  def run(suite_attrs, variant_matrix, opts \\ [])

  def run(suite_attrs, variant_matrix, opts)
      when is_map(suite_attrs) and is_list(variant_matrix) and is_list(opts) do
    with :ok <- bounded_matrix(variant_matrix),
         {:ok, variants} <- validate_variants(variant_matrix),
         {:ok, runs} <- run_variants(suite_attrs, variants, opts) do
      {:ok,
       %{
         eval_run_ref: batch_ref(runs),
         suite_ref: Map.get(suite_attrs, :suite_ref) || Map.get(suite_attrs, "suite_ref"),
         verdict: compose_verdict(runs),
         case_decisions: Enum.flat_map(runs, & &1.case_projections),
         variant_runs: Enum.map(runs, &project_run/1)
       }}
    end
  end

  def run(_suite_attrs, _variant_matrix, _opts), do: {:error, :invalid_eval_runner_input}

  defp bounded_matrix([]), do: {:error, :eval_variant_matrix_missing}

  defp bounded_matrix(matrix) when length(matrix) <= @max_variants, do: :ok

  defp bounded_matrix(_matrix), do: {:error, :eval_variant_matrix_unbounded}

  defp validate_variants(matrix) do
    Enum.reduce_while(matrix, {:ok, []}, fn variant, {:ok, variants} ->
      case validate_variant(variant) do
        {:ok, validated} -> {:cont, {:ok, [validated | variants]}}
        {:error, reason} -> {:halt, {:error, reason}}
      end
    end)
    |> case do
      {:ok, variants} -> {:ok, Enum.reverse(variants)}
      error -> error
    end
  end

  defp validate_variant(variant) when is_map(variant) do
    with :ok <- reject_raw(variant),
         :ok <- required_variant_refs(variant),
         {:ok, prompt_revision} <- positive_integer(variant, :prompt_revision) do
      {:ok, Map.put(variant, :prompt_revision, prompt_revision)}
    end
  end

  defp validate_variant(_variant), do: {:error, :invalid_eval_variant}

  defp run_variants(suite_attrs, variants, opts) do
    Enum.reduce_while(variants, {:ok, []}, fn variant, {:ok, runs} ->
      case EvalEngine.run(suite_attrs, variant, opts) do
        {:ok, run} -> {:cont, {:ok, [run | runs]}}
        {:error, reason} -> {:halt, {:error, reason}}
      end
    end)
    |> case do
      {:ok, runs} -> {:ok, Enum.reverse(runs)}
      error -> error
    end
  end

  defp compose_verdict(runs) do
    runs
    |> Enum.map(& &1.verdict)
    |> Enum.max_by(&verdict_rank/1)
  end

  defp verdict_rank(:pass), do: 0
  defp verdict_rank(:improve), do: 1
  defp verdict_rank(:inconclusive), do: 2
  defp verdict_rank(:regress), do: 3

  defp project_run(run) do
    %{
      eval_run_ref: run.eval_run_ref,
      suite_ref: run.suite_ref,
      variant_ref: run.variant_ref,
      verdict: run.verdict,
      cost_class: run.cost_class
    }
  end

  defp batch_ref(runs) do
    runs
    |> Enum.map_join("|", & &1.eval_run_ref)
    |> hash()
    |> then(&("eval-run-batch://" <> &1))
  end

  defp required_variant_refs(variant) do
    case Enum.find(@required_variant_fields, &(not present?(fetch(variant, &1)))) do
      nil -> :ok
      field -> {:error, {:missing_eval_variant_ref, field}}
    end
  end

  defp reject_raw(attrs) do
    case Enum.find(@raw_keys, &Map.has_key?(attrs, &1)) do
      nil -> :ok
      key -> {:error, {:raw_eval_runner_payload_forbidden, key}}
    end
  end

  defp positive_integer(attrs, field) do
    case fetch(attrs, field) do
      integer when is_integer(integer) and integer > 0 -> {:ok, integer}
      _other -> {:error, {:invalid_eval_variant_ref, field}}
    end
  end

  defp present?(value) when is_binary(value), do: String.trim(value) != ""
  defp present?(value) when is_integer(value), do: value > 0
  defp present?(value), do: not is_nil(value)
  defp fetch(attrs, field), do: Map.get(attrs, field) || Map.get(attrs, Atom.to_string(field))
  defp hash(value), do: :crypto.hash(:sha256, value) |> Base.encode16(case: :lower)
end
