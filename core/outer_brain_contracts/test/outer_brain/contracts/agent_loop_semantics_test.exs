defmodule OuterBrain.Contracts.AgentLoopSemanticsTest do
  use ExUnit.Case, async: true

  alias OuterBrain.Contracts.{CandidateFact, CandidateFactSet, ReflectionResult}

  test "ReflectionResult is a strict one-variant tagged union" do
    assert {:ok, action} =
             ReflectionResult.new(%{
               result_ref: "reflection://turn-1",
               variant: :action_request,
               action_request_ref: "action://turn-1",
               risk_band: :low,
               confidence_band: :high,
               trace_id: "trace://local/1"
             })

    assert action.variant == :action_request

    assert ReflectionResult.workflow_history_payload(action).action_request_ref ==
             "action://turn-1"

    assert {:error, :invalid_reflection_result} =
             ReflectionResult.new(%{
               result_ref: "reflection://turn-1",
               variant: :action_request,
               action_request_ref: "action://turn-1",
               final_answer_ref: "answer://turn-1",
               risk_band: :low,
               confidence_band: :high,
               trace_id: "trace://local/1"
             })
  end

  test "CandidateFact proposals carry refs, confidence/risk bands, and no raw payloads" do
    assert {:ok, fact} =
             CandidateFact.new(%{
               candidate_fact_ref: "candidate-fact://turn-1/1",
               fact_kind: :tool_observation,
               confidence_class: :observed,
               confidence_band: :high,
               risk_band: :low,
               source_observation_ref: "observation://turn-1",
               evidence_ref: "evidence://turn-1",
               redaction_ref: "redaction://public-safe",
               redaction_class: :claim_checked,
               claim_check_refs: ["claim://tool-output/turn-1"],
               proposed_by: "outer-brain://fixture-reflector",
               trace_id: "trace://local/1"
             })

    assert CandidateFact.to_payload(fact)["confidence_band"] == "high"

    assert CandidateFact.workflow_history_payload(fact).candidate_fact_ref ==
             "candidate-fact://turn-1/1"

    assert {:error, :invalid_candidate_fact} =
             CandidateFact.new(%{
               candidate_fact_ref: "candidate-fact://turn-1/1",
               fact_kind: :tool_observation,
               confidence_class: :observed,
               confidence_band: :high,
               risk_band: :low,
               source_observation_ref: "observation://turn-1",
               evidence_ref: "evidence://turn-1",
               redaction_ref: "redaction://public-safe",
               redaction_class: :claim_checked,
               claim_check_refs: ["claim://tool-output/turn-1"],
               proposed_by: "outer-brain://fixture-reflector",
               trace_id: "trace://local/1",
               raw_provider_payload: %{}
             })
  end

  test "CandidateFactSet remains proposal-shaped and cannot claim private memory truth" do
    attrs = %{
      candidate_fact_set_ref: "candidate-fact-set://turn-1",
      candidate_facts: [candidate_fact_attrs()],
      fact_extraction_receipt_ref: "fact-extraction-receipt://turn-1",
      source_observation_refs: ["observation://turn-1"],
      proposed_by: "outer-brain://semanticize",
      trace_id: "trace://local/1"
    }

    assert {:ok, set} = CandidateFactSet.new(attrs)
    payload = CandidateFactSet.workflow_history_payload(set)

    assert payload.candidate_fact_refs == ["candidate-fact://turn-1/1"]
    refute Map.has_key?(payload, :memory_commit_ref)
    refute inspect(CandidateFactSet.to_payload(set)) =~ "PrivateWriter"

    assert {:error, :invalid_candidate_fact_set} =
             attrs
             |> Map.put(:memory_commit_ref, "memory-commit://not-outer-brain")
             |> CandidateFactSet.new()

    assert {:error, :invalid_candidate_fact_set} =
             attrs
             |> put_in([:candidate_facts], [])
             |> CandidateFactSet.new()
  end

  test "OuterBrain contracts do not call the Mezzanine PrivateWriter boundary" do
    contract_files = Path.wildcard("lib/**/*.ex")

    assert contract_files != []

    Enum.each(contract_files, fn path ->
      refute path |> File.read!() |> String.contains?("Mezzanine.PrivateWriter"),
             "#{path} bypasses the Mezzanine memory writer boundary"
    end)
  end

  defp candidate_fact_attrs do
    %{
      candidate_fact_ref: "candidate-fact://turn-1/1",
      fact_kind: :tool_observation,
      confidence_class: :observed,
      confidence_band: :high,
      risk_band: :low,
      source_observation_ref: "observation://turn-1",
      evidence_ref: "evidence://turn-1",
      redaction_ref: "redaction://public-safe",
      redaction_class: :claim_checked,
      claim_check_refs: ["claim://tool-output/turn-1"],
      proposed_by: "outer-brain://fixture-reflector",
      trace_id: "trace://local/1"
    }
  end
end
