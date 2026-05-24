defmodule OuterBrain.Prompting.ContextRendererTest do
  use ExUnit.Case, async: true

  alias OuterBrain.ContextABI
  alias OuterBrain.ContextABI.Failure
  alias OuterBrain.Prompting.ContextRenderer

  test "fixture renderer returns prompt and provider payload refs with a stable payload hash" do
    assert {:ok, packet, _receipt} = ContextABI.compile(compile_request())

    profile = %{
      provider_family: "fixture",
      model_class: "class://coding-small",
      payload_mode: :ref_only
    }

    assert {:ok, rendered} = ContextRenderer.Fixture.render(packet, profile)
    assert {:ok, rendered_again} = ContextRenderer.Fixture.render(packet, profile)

    assert rendered == rendered_again
    assert rendered.prompt_artifact_ref =~ ~r/^prompt-artifact:\/\/[0-9a-f]{64}$/
    assert rendered.provider_payload_ref =~ ~r/^provider-payload:\/\/[0-9a-f]{64}$/
    assert rendered.provider_family == "fixture"
    assert rendered.message_count == 3
    assert rendered.token_estimate > 0
    assert rendered.payload_hash =~ ~r/^sha256:[0-9a-f]{64}$/
    assert rendered.trace_ref == packet.trace_ref
    refute Map.has_key?(rendered, :raw_prompt)
    refute Map.has_key?(rendered, :provider_payload)
  end

  test "fixture renderer rejects unsupported payload modes through Context ABI failure shape" do
    assert {:ok, packet, _receipt} = ContextABI.compile(compile_request())

    assert {:error, %Failure{} = failure} =
             ContextRenderer.Fixture.render(packet, %{
               provider_family: "fixture",
               model_class: "class://coding-small",
               payload_mode: :raw_debug
             })

    assert failure.owner == :outer_brain
    assert failure.reason_code == "outer_brain.prompting.payload_mode_denied.v1"
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
