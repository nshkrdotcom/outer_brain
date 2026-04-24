defmodule OuterBrain.Memory.RecallOrchestratorTest do
  use ExUnit.Case, async: true

  alias OuterBrain.Memory.RecallOrchestrator

  test "recall pins one epoch, filters by effective access, transforms, and emits proof" do
    test_pid = self()
    request = recall_request()

    callbacks = [
      snapshot_pin: fn ^request ->
        send(test_pid, :snapshot_pinned)
        {:ok, ordering_evidence()}
      end,
      access_graph_views: fn context ->
        send(test_pid, {:graph_epoch, context.snapshot_epoch})

        {:ok,
         %{
           authorized_agent_refs: ["agent://alpha"],
           shared_scope_refs: ["scope://team"],
           governed_policy_refs: ["promote-policy://stable"]
         }}
      end,
      read_policy: fn context ->
        send(test_pid, {:read_policy_epoch, context.snapshot_epoch})

        {:ok,
         %{
           policy_ref: "read-policy://alpha",
           transform_policy: %{pipeline_ref: "transform://recall-redact"},
           degraded_behavior: :fail_closed
         }}
      end,
      tier_reader: fn tier, context ->
        send(test_pid, {:tier_read, tier, context.snapshot_epoch})
        {:ok, tier_fragments(tier)}
      end,
      transform: fn fragments, context ->
        send(
          test_pid,
          {:transform, Enum.map(fragments, & &1.fragment_id), context.read_policy.policy_ref}
        )

        {:ok, Enum.map(fragments, &put_in(&1, [:metadata, :transformed?], true))}
      end,
      proof_emitter: fn context ->
        send(
          test_pid,
          {:proof, Enum.map(context.transformed_fragments, & &1.fragment_id),
           context.snapshot_epoch}
        )

        assert Enum.all?(context.transformed_fragments, &get_in(&1, [:metadata, :transformed?]))

        {:ok,
         %{
           proof_id: "proof://recall/alpha",
           kind: :recall,
           snapshot_epoch: context.snapshot_epoch,
           source_node_ref: context.source_node_ref,
           commit_lsn: context.commit_lsn,
           commit_hlc: context.commit_hlc,
           fragment_ids: Enum.map(context.transformed_fragments, & &1.fragment_id)
         }}
      end
    ]

    assert {:ok, result} = RecallOrchestrator.recall(request, callbacks)

    assert result.snapshot_epoch == 42
    assert result.proof_token.proof_id == "proof://recall/alpha"

    assert Enum.map(result.admitted_fragments, & &1.fragment_id) == [
             "private-allowed",
             "shared-allowed",
             "governed-allowed"
           ]

    assert Enum.all?(result.context_pack_fragments, &get_in(&1, [:metadata, :transformed?]))

    assert_received :snapshot_pinned
    assert_received {:graph_epoch, 42}
    assert_received {:read_policy_epoch, 42}
    assert_received {:tier_read, :private, 42}
    assert_received {:tier_read, :shared, 42}
    assert_received {:tier_read, :governed, 42}

    assert_received {:transform, ["private-allowed", "shared-allowed", "governed-allowed"],
                     "read-policy://alpha"}

    assert_received {:proof, ["private-allowed", "shared-allowed", "governed-allowed"], 42}
  end

  test "unauthorized agents fail before tier reads or proof emission" do
    test_pid = self()

    callbacks = [
      snapshot_pin: fn _request -> {:ok, ordering_evidence()} end,
      access_graph_views: fn _context -> {:ok, %{authorized_agent_refs: ["agent://other"]}} end,
      tier_reader: fn tier, _context ->
        send(test_pid, {:unexpected_tier_read, tier})
        {:ok, []}
      end,
      proof_emitter: fn _context ->
        send(test_pid, :unexpected_proof)
        {:ok, %{}}
      end
    ]

    assert {:error, {:unauthorized_agent, "agent://alpha"}} =
             RecallOrchestrator.recall(recall_request(), callbacks)

    refute_received {:unexpected_tier_read, _tier}
    refute_received :unexpected_proof
  end

  test "fail-empty read policy degradation still emits an empty recall proof" do
    test_pid = self()

    callbacks = [
      snapshot_pin: fn _request -> {:ok, ordering_evidence()} end,
      access_graph_views: fn _context ->
        {:ok, %{authorized_agent_refs: ["agent://alpha"], shared_scope_refs: []}}
      end,
      read_policy: fn _context ->
        {:error, {:degraded, :fail_empty, :policy_registry_unavailable}}
      end,
      proof_emitter: fn context ->
        send(test_pid, {:degraded_proof, context.outcome, context.degraded_reason})

        {:ok,
         %{
           proof_id: "proof://recall/fail-empty",
           kind: :recall,
           snapshot_epoch: context.snapshot_epoch,
           fragment_ids: []
         }}
      end
    ]

    assert {:ok, result} = RecallOrchestrator.recall(recall_request(), callbacks)

    assert result.admitted_fragments == []
    assert result.context_pack_fragments == []
    assert result.proof_token.proof_id == "proof://recall/fail-empty"
    assert_received {:degraded_proof, :fail_empty, :policy_registry_unavailable}
  end

  test "fail-closed policy degradation stops before tier reads or proof emission" do
    test_pid = self()

    callbacks = [
      snapshot_pin: fn _request -> {:ok, ordering_evidence()} end,
      access_graph_views: fn _context ->
        {:ok, %{authorized_agent_refs: ["agent://alpha"], shared_scope_refs: []}}
      end,
      read_policy: fn _context ->
        {:error, {:degraded, :fail_closed, :policy_registry_unavailable}}
      end,
      tier_reader: fn tier, _context ->
        send(test_pid, {:unexpected_tier_read, tier})
        {:ok, []}
      end,
      proof_emitter: fn _context ->
        send(test_pid, :unexpected_proof)
        {:ok, %{}}
      end
    ]

    assert {:error, {:policy_degraded, :policy_registry_unavailable}} =
             RecallOrchestrator.recall(recall_request(), callbacks)

    refute_received {:unexpected_tier_read, _tier}
    refute_received :unexpected_proof
  end

  test "fail-partial policy degradation continues with proof evidence" do
    test_pid = self()

    callbacks = [
      snapshot_pin: fn _request -> {:ok, ordering_evidence()} end,
      access_graph_views: fn _context ->
        {:ok,
         %{
           authorized_agent_refs: ["agent://alpha"],
           shared_scope_refs: ["scope://team"],
           governed_policy_refs: ["promote-policy://stable"]
         }}
      end,
      read_policy: fn _context ->
        {:error, {:degraded, :fail_partial, :policy_registry_stale}}
      end,
      tier_reader: fn tier, context ->
        send(test_pid, {:partial_tier_read, tier, context.read_policy.degraded_reason})
        {:ok, tier_fragments(tier)}
      end,
      proof_emitter: fn context ->
        send(test_pid, {:partial_proof, context.read_policy.degraded_reason})
        {:ok, %{proof_id: "proof://recall/fail-partial", kind: :recall}}
      end
    ]

    assert {:ok, result} = RecallOrchestrator.recall(recall_request(), callbacks)

    assert Enum.map(result.admitted_fragments, & &1.fragment_id) == [
             "private-allowed",
             "shared-allowed",
             "governed-allowed"
           ]

    assert_received {:partial_tier_read, :private, :policy_registry_stale}
    assert_received {:partial_tier_read, :shared, :policy_registry_stale}
    assert_received {:partial_tier_read, :governed, :policy_registry_stale}
    assert_received {:partial_proof, :policy_registry_stale}
  end

  test "concurrent revocation after the pin cannot change the epoch used by tiers or proof" do
    test_pid = self()

    callbacks = [
      snapshot_pin: fn _request ->
        Process.put(:current_epoch, 42)
        {:ok, ordering_evidence()}
      end,
      access_graph_views: fn context ->
        assert context.snapshot_epoch == 42

        {:ok,
         %{
           authorized_agent_refs: ["agent://alpha"],
           shared_scope_refs: ["scope://team"],
           governed_policy_refs: ["promote-policy://stable"]
         }}
      end,
      read_policy: fn _context -> {:ok, %{policy_ref: "read-policy://alpha"}} end,
      tier_reader: fn tier, context ->
        if tier == :private do
          Process.put(:current_epoch, 43)
        end

        send(
          test_pid,
          {:revocation_tier_epoch, tier, context.snapshot_epoch, Process.get(:current_epoch)}
        )

        {:ok, tier_fragments(tier)}
      end,
      proof_emitter: fn context ->
        send(
          test_pid,
          {:revocation_proof_epoch, context.snapshot_epoch, Process.get(:current_epoch)}
        )

        {:ok, %{proof_id: "proof://recall/concurrent-revocation", kind: :recall}}
      end
    ]

    assert {:ok, result} = RecallOrchestrator.recall(recall_request(), callbacks)

    assert result.snapshot_epoch == 42
    assert_received {:revocation_tier_epoch, :private, 42, 43}
    assert_received {:revocation_tier_epoch, :shared, 42, 43}
    assert_received {:revocation_tier_epoch, :governed, 42, 43}
    assert_received {:revocation_proof_epoch, 42, 43}
  end

  defp recall_request do
    %{
      tenant_ref: "tenant://alpha",
      user_ref: "user://alpha",
      agent_ref: "agent://alpha",
      trace_id: "trace-recall-alpha",
      source_node_ref: "node://memory-reader@host/reader-1",
      top_k_by_tier: %{private: 1, shared: 1, governed: 1},
      input: %{query: "recent decision"}
    }
  end

  defp ordering_evidence do
    %{
      snapshot_epoch: 42,
      pinned_at: ~U[2026-04-24 16:00:00Z],
      source_node_ref: "node://memory-reader@host/reader-1",
      commit_lsn: "16/B374D848",
      commit_hlc: %{wall_ns: 1_800_000_000_000_000_000, logical: 1, node: "reader-1"}
    }
  end

  defp tier_fragments(:private) do
    [
      %{
        fragment_id: "private-allowed",
        tier: :private,
        user_ref: "user://alpha",
        score: 0.91,
        content: %{body: "private memory"},
        access: %{user_refs: ["user://alpha"], agent_refs: ["agent://alpha"]},
        metadata: %{}
      },
      %{
        fragment_id: "private-filtered",
        tier: :private,
        user_ref: "user://beta",
        score: 0.99,
        content: %{body: "wrong user"},
        access: %{user_refs: ["user://beta"], agent_refs: ["agent://alpha"]},
        metadata: %{}
      }
    ]
  end

  defp tier_fragments(:shared) do
    [
      %{
        fragment_id: "shared-allowed",
        tier: :shared,
        scope_refs: ["scope://team"],
        score: 0.82,
        content: %{body: "shared memory"},
        access: %{scope_refs: ["scope://team"], agent_refs: ["agent://alpha"]},
        metadata: %{}
      },
      %{
        fragment_id: "shared-filtered",
        tier: :shared,
        scope_refs: ["scope://other"],
        score: 0.95,
        content: %{body: "wrong scope"},
        access: %{scope_refs: ["scope://other"], agent_refs: ["agent://alpha"]},
        metadata: %{}
      }
    ]
  end

  defp tier_fragments(:governed) do
    [
      %{
        fragment_id: "governed-allowed",
        tier: :governed,
        score: 0.73,
        content: %{body: "governed memory"},
        access: %{agent_refs: ["agent://alpha"], governance_valid?: true},
        promote_policy_ref: "promote-policy://stable",
        metadata: %{}
      },
      %{
        fragment_id: "governed-filtered",
        tier: :governed,
        score: 0.97,
        content: %{body: "stale governed memory"},
        access: %{agent_refs: ["agent://alpha"], governance_valid?: false},
        promote_policy_ref: "promote-policy://stale",
        metadata: %{}
      }
    ]
  end
end
