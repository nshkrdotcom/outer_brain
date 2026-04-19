defmodule OuterBrain.Bridges.DomainSubmissionTest do
  use ExUnit.Case, async: true

  alias Citadel.DomainSurface.Adapters.CitadelAdapter.Accepted
  alias OuterBrain.Bridges.DomainSubmission

  defmodule GhostRoute do
    @moduledoc false

    alias Citadel.DomainSurface.Route

    @behaviour Route

    def definition do
      Route.definition!(
        name: :ghost_route,
        request_type: :command,
        operation: :ghost_route,
        dispatch_via: :kernel_runtime,
        version: "1.0.0",
        description: "Route declared in the semantic manifest but absent from the domain module",
        orchestration: :stateless_sync,
        semantic_metadata: %{category: :workspace, intent: "ghost route", tags: [:ghost]},
        tool_manifest: %{
          summary: "Exercise unavailable route handling",
          examples: [%{workspace_id: "workspace/main"}],
          stability: :stable
        }
      )
    end
  end

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

  test "emits a provider-neutral semantic failure carrier for semantic selection ambiguity" do
    assert {:error, {:semantic_failure, carrier}} =
             DomainSubmission.submit_turn(
               "do something useful later",
               session_id: "session-semantic-2",
               tenant_id: "tenant-semantic",
               actor_id: "actor-semantic",
               environment: "dev",
               scope_id: "workspace/main",
               workspace_root: "/workspace/main",
               idempotency_key: "semantic-turn-2",
               trace_id: "trace/semantic-turn-2",
               domain_module: Citadel.DomainSurface.Examples.ProvingGround,
               route_sources: [
                 Citadel.DomainSurface.Examples.ProvingGround.Routes.CompileWorkspace,
                 Citadel.DomainSurface.Examples.ProvingGround.Routes.WorkspaceStatus
               ],
               kernel_runtime: {FakeKernelRuntime, []}
             )

    assert carrier.kind == :semantic_insufficient_context
    assert carrier.retry_class == :clarification_required
    assert carrier.tenant_id == "tenant-semantic"
    assert carrier.semantic_session_id == "session-semantic-2"
    assert carrier.causal_unit_id == "semantic-turn-2"
    assert carrier.request_trace_id == "trace/semantic-turn-2"
    assert [%{"surface" => "outer_brain.domain_submission"}] = carrier.provenance
  end

  test "emits a semantic tool-mismatch carrier when the selected route is absent from the domain module" do
    assert {:error, {:semantic_failure, carrier}} =
             DomainSubmission.submit_turn(
               "route this ghost request",
               session_id: "session-semantic-3",
               tenant_id: "tenant-semantic",
               actor_id: "actor-semantic",
               environment: "dev",
               scope_id: "workspace/main",
               workspace_root: "/workspace/main",
               idempotency_key: "semantic-turn-3",
               trace_id: "trace/semantic-turn-3",
               domain_module: Citadel.DomainSurface.Examples.ProvingGround,
               route_sources: [GhostRoute],
               kernel_runtime: {FakeKernelRuntime, []}
             )

    assert carrier.kind == :semantic_tool_mismatch
    assert carrier.retry_class == :repairable
    assert carrier.tenant_id == "tenant-semantic"
    assert carrier.semantic_session_id == "session-semantic-3"
    assert carrier.causal_unit_id == "semantic-turn-3"
    assert carrier.request_trace_id == "trace/semantic-turn-3"
  end
end
