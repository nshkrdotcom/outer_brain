defmodule OuterBrain.Contracts.AgentLoopSemanticsTest do
  use ExUnit.Case, async: true

  alias OuterBrain.Contracts.{CandidateFact, ReflectionResult}

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
end
