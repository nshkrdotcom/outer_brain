defmodule OuterBrain.EvalRunnerTest do
  use ExUnit.Case, async: true

  alias OuterBrain.EvalRunner

  test "runs bounded variant matrices and returns ref-only decisions" do
    assert {:ok, result} = EvalRunner.run(suite_attrs(), [variant()], max_concurrency: 1)

    assert result.verdict == :pass
    assert [%{cost_class: :eval}] = result.variant_runs
    refute Map.has_key?(result, :model_output)
  end

  test "rejects unbounded matrices, missing refs, and raw model output" do
    assert {:error, :eval_variant_matrix_missing} = EvalRunner.run(suite_attrs(), [])

    assert {:error, :eval_variant_matrix_unbounded} =
             EvalRunner.run(suite_attrs(), List.duplicate(variant(), 17))

    assert {:error, {:missing_eval_variant_ref, :guard_chain_ref}} =
             EvalRunner.run(suite_attrs(), [Map.delete(variant(), :guard_chain_ref)])

    assert {:error, {:raw_eval_runner_payload_forbidden, :model_output}} =
             EvalRunner.run(suite_attrs(), [Map.put(variant(), :model_output, "raw")])
  end

  defp suite_attrs do
    %{
      suite_ref: "eval-suite://phase-c",
      tenant_ref: "tenant://a",
      authority_ref: "authority://a",
      installation_ref: "installation://a",
      idempotency_key: "idem-eval-runner",
      trace_ref: "trace://eval-runner",
      regression_oracle: :exact_shape,
      release_manifest_ref: "release://phase-c",
      cases: [
        %{
          case_ref: "case-1",
          input_prompt_ref: "prompt://phase-c",
          expected_output_ref: "eval-output://case-1",
          expected_shape: %{tool: "call"},
          observed_shape: %{tool: "call"}
        }
      ]
    }
  end

  defp variant do
    %{
      prompt_revision: 1,
      model_ref: "model://deterministic",
      policy_revision: "policy://phase-c",
      guard_chain_ref: "guard-chain://phase-c",
      memory_profile_ref: "memory-profile://fixture"
    }
  end
end
