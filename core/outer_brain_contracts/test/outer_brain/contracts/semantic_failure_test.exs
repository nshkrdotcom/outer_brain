defmodule OuterBrain.Contracts.SemanticFailureTest do
  use ExUnit.Case, async: true

  alias OuterBrain.Contracts.SemanticFailure

  test "normalizes a provider-neutral semantic failure carrier" do
    assert {:ok, failure} =
             SemanticFailure.new(%{
               "kind" => "semantic_insufficient_context",
               "tenant_id" => "tenant-1",
               "semantic_session_id" => "session-1",
               "causal_unit_id" => "turn-1",
               "request_trace_id" => "trace-1",
               "provenance" => [%{"source" => "context_adapter"}],
               "context_hash" => "sha256:context",
               "provider_ref" => %{"provider" => "semantic-host"},
               "operator_message" => "Additional workspace context is required."
             })

    assert failure.kind == :semantic_insufficient_context
    assert failure.retry_class == :clarification_required
    assert failure.provenance == [%{"source" => "context_adapter"}]
    assert failure.provider_ref == %{"provider" => "semantic-host"}

    assert %{
             "kind" => "semantic_insufficient_context",
             "retry_class" => "clarification_required",
             "tenant_id" => "tenant-1",
             "semantic_session_id" => "session-1",
             "causal_unit_id" => "turn-1",
             "request_trace_id" => "trace-1",
             "substrate_trace_id" => nil,
             "provenance" => [%{"source" => "context_adapter"}],
             "context_hash" => "sha256:context",
             "provider_ref" => %{"provider" => "semantic-host"},
             "operator_message" => "Additional workspace context is required."
           } = SemanticFailure.to_payload(failure)

    assert {:ok, ^failure} =
             failure |> SemanticFailure.to_payload() |> SemanticFailure.from_payload()
  end

  test "rejects non-contract failure kinds and invalid provenance" do
    base = %{
      kind: :semantic_insufficient_context,
      tenant_id: "tenant-1",
      semantic_session_id: "session-1",
      causal_unit_id: "turn-1",
      request_trace_id: "trace-1",
      operator_message: "Need more context."
    }

    assert {:error, {:invalid_semantic_failure_kind, :provider_timeout}} =
             base
             |> Map.put(:kind, :provider_timeout)
             |> SemanticFailure.new()

    assert {:error, {:invalid_semantic_failure_kind, "provider_timeout"}} =
             base
             |> Map.put(:kind, "provider_timeout")
             |> SemanticFailure.new()

    assert {:error, :invalid_semantic_failure_provenance} =
             base
             |> Map.put(:provenance, %{"source" => "not-a-list"})
             |> SemanticFailure.new()
  end
end
