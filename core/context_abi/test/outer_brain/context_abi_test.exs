defmodule OuterBrain.ContextABITest do
  use ExUnit.Case, async: true

  alias OuterBrain.ContextABI
  alias OuterBrain.ContextABI.{ContextPacket, ContextPacketReceipt, ContextUnit, Failure}

  test "compiles the frozen MVP packet contract with deterministic refs and receipt" do
    assert {:ok, %ContextPacket{} = packet, %ContextPacketReceipt{} = receipt} =
             ContextABI.compile(compile_request())

    assert packet.schema_ref == "outer_brain.context_packet.mvp.v1"
    assert packet.context_packet_ref =~ ~r/^context-packet:\/\/[0-9a-f]{64}$/
    assert packet.packet_hash =~ ~r/^sha256:[0-9a-f]{64}$/
    assert packet.memory_refs == ["memory://tenant-a/promoted/a"]
    assert receipt.status == :compiled
    assert receipt.packet_hash == packet.packet_hash
    assert receipt.context_packet_ref == packet.context_packet_ref

    assert receipt.included_refs == [
             "artifact://tenant-a/request/a",
             "artifact://tenant-a/system/a",
             "memory://tenant-a/promoted/a"
           ]
  end

  test "packet hash is independent of input map key order" do
    left = compile_request()

    right = %{
      "trace_ref" => "trace://tenant-a/run/a",
      "route_policy_ref" => "route-policy://tenant-a/default",
      "model_class_allowlist" => ["class://coding-small"],
      "budget_ref" => "budget://tenant-a/run/a",
      "memory_refs" => ["memory://tenant-a/promoted/a"],
      "system_instruction_ref" => "artifact://tenant-a/system/a",
      "user_request_ref" => "artifact://tenant-a/request/a",
      "tenant_ref" => "tenant://tenant-a"
    }

    assert {:ok, left_packet, _left_receipt} = ContextABI.compile(left)
    assert {:ok, right_packet, _right_receipt} = ContextABI.compile(right)

    assert left_packet.packet_hash == right_packet.packet_hash
    assert left_packet.context_packet_ref == right_packet.context_packet_ref
  end

  test "compiler rejects raw prompt, memory, provider, and credential payloads" do
    assert {:error, %Failure{} = failure} =
             compile_request()
             |> Map.put(:metadata, %{raw_prompt: "never inline"})
             |> ContextABI.compile()

    assert failure.owner == :outer_brain
    assert failure.reason_code == "outer_brain.context.raw_payload_rejected.v1"

    assert {:error, %Failure{} = nested_failure} =
             compile_request()
             |> Map.put(:extension_refs, %{"provider_payload" => "never inline"})
             |> ContextABI.compile()

    assert nested_failure.reason_code == "outer_brain.context.raw_payload_rejected.v1"
  end

  test "context units validate vocabulary and reject raw metadata payloads" do
    assert {:ok, %ContextUnit{} = unit} =
             ContextUnit.new(%{
               context_unit_ref: "context-unit://tenant-a/memory/a",
               tenant_ref: "tenant://tenant-a",
               unit_kind: :memory,
               artifact_ref: "memory://tenant-a/promoted/a",
               source_ref: "memory-source://tenant-a/promoted",
               trust_class: :memory_promoted,
               redaction_class: :ref_only,
               trace_ref: "trace://tenant-a/run/a",
               metadata: %{rank: "1"}
             })

    assert unit.schema_ref == "outer_brain.context_unit.mvp.v1"

    assert {:error, %Failure{} = trust_failure} =
             ContextUnit.new(%{
               context_unit_ref: "context-unit://tenant-a/memory/a",
               tenant_ref: "tenant://tenant-a",
               unit_kind: :memory,
               artifact_ref: "memory://tenant-a/promoted/a",
               source_ref: "memory-source://tenant-a/promoted",
               trust_class: :unbounded_external_claim,
               redaction_class: :ref_only,
               trace_ref: "trace://tenant-a/run/a"
             })

    assert trust_failure.reason_code == "outer_brain.context.invalid_trust_class.v1"

    assert {:error, %Failure{} = raw_failure} =
             ContextUnit.new(%{
               context_unit_ref: "context-unit://tenant-a/memory/a",
               tenant_ref: "tenant://tenant-a",
               unit_kind: :memory,
               artifact_ref: "memory://tenant-a/promoted/a",
               source_ref: "memory-source://tenant-a/promoted",
               trust_class: :memory_promoted,
               redaction_class: :ref_only,
               trace_ref: "trace://tenant-a/run/a",
               metadata: %{memory_body: "not allowed"}
             })

    assert raw_failure.reason_code == "outer_brain.context.raw_payload_rejected.v1"
  end

  test "failure reason codes are owner-local and safe" do
    assert {:ok, %Failure{} = failure} =
             Failure.new(%{
               owner: :citadel,
               reason_code: "citadel.authority.model_class_denied.v1",
               safe_message: "model class denied",
               retryable?: false,
               trace_ref: "trace://tenant-a/run/a",
               evidence_refs: ["evidence://citadel/a"]
             })

    assert failure.owner == :citadel

    assert {:error, :reason_code_owner_mismatch} =
             Failure.new(%{
               owner: :citadel,
               reason_code: "outer_brain.context.invalid.v1",
               safe_message: "invalid"
             })
  end

  defp compile_request do
    %{
      tenant_ref: "tenant://tenant-a",
      user_request_ref: "artifact://tenant-a/request/a",
      system_instruction_ref: "artifact://tenant-a/system/a",
      memory_refs: ["memory://tenant-a/promoted/a"],
      budget_ref: "budget://tenant-a/run/a",
      model_class_allowlist: ["class://coding-small"],
      route_policy_ref: "route-policy://tenant-a/default",
      trace_ref: "trace://tenant-a/run/a"
    }
  end
end
