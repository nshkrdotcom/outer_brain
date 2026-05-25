defmodule OuterBrain.RemoteFacade.ContextTest do
  use ExUnit.Case, async: true

  alias OuterBrain.RemoteFacade.Context

  test "declares owner-defined context group" do
    assert Context.owner_group() == {Context, :context}
  end

  test "compiles context request into serializable packet and receipt maps" do
    assert {:ok, result} = Context.compile_context(valid_request())

    assert result["context_packet"]["tenant_ref"] == "tenant://one"
    assert result["context_packet"]["packet_hash"]
    assert result["receipt"]["status"] == "compiled"
    assert result["receipt"]["trace_ref"] == "trace://one"
  end

  test "rejects invalid context request with safe failure map" do
    assert {:error, %{"code" => "context_compile_failed", "reason_code" => reason_code}} =
             valid_request()
             |> Map.delete("tenant_ref")
             |> Context.compile_context()

    assert String.starts_with?(reason_code, "outer_brain.context.")
  end

  test "readback returns bounded ref-only context facts" do
    assert {:ok, readback} = Context.readback_context("context-packet://one")

    assert readback["context_packet_ref"] == "context-packet://one"
    assert readback["payload_mode"] == "refs_only"
  end

  defp valid_request do
    %{
      "tenant_ref" => "tenant://one",
      "user_request_ref" => "user-request://one",
      "system_instruction_ref" => "system-instruction://one",
      "memory_refs" => ["memory://promoted/one"],
      "budget_ref" => "budget://one",
      "model_class_allowlist" => ["model-class://small"],
      "route_policy_ref" => "route-policy://one",
      "trace_ref" => "trace://one"
    }
  end
end
