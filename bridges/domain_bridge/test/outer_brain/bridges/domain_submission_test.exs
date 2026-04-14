defmodule OuterBrain.Bridges.DomainSubmissionTest do
  use ExUnit.Case, async: true

  alias Citadel.DomainSurface.Adapters.CitadelAdapter.Accepted
  alias OuterBrain.Bridges.DomainSubmission

  defmodule FakeKernelRuntime do
    @moduledoc false

    def dispatch_command(command, _opts) do
      {:ok,
       Accepted.new!(%{
         request_id: command.idempotency_key,
         session_id: command.context[:session_id],
         trace_id: command.trace_id,
         ingress_path: :direct_intent_envelope,
         lifecycle_event: :live_owner,
         continuity_revision: 1
       })}
    end
  end

  test "submits a semantic turn through citadel_domain_surface using the typed route boundary" do
    assert {:ok, result} =
             DomainSubmission.submit_turn(
               "compile the workspace",
               session_id: "session-semantic-1",
               tenant_id: "tenant-semantic",
               actor_id: "actor-semantic",
               environment: "dev",
               scope_id: "workspace/main",
               workspace_root: "/workspace/main",
               idempotency_key: "semantic-turn-1",
               trace_id: "trace/semantic-turn-1",
               domain_module: Citadel.DomainSurface.Examples.ProvingGround,
               route_sources: [
                 Citadel.DomainSurface.Examples.ProvingGround.Routes.CompileWorkspace
               ],
               kernel_runtime: {FakeKernelRuntime, []}
             )

    assert result.action_request.route == "compile_workspace"
    assert result.action_request.args.workspace_id == "workspace/main"
    assert %Accepted{} = result.dispatch_result
    assert result.dispatch_result.request_id == "semantic-turn-1"
    assert result.manifest_id == "manifest_domain"
  end
end
