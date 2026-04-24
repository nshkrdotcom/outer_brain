defmodule OuterBrain.Runtime.MemoryOperationBindingsTest do
  use ExUnit.Case, async: true

  alias OuterBrain.Memory.{PrivateWriter, RecallOrchestrator, ShareUpClient}
  alias OuterBrain.Runtime.MemoryInvalidationConsumer
  alias OuterBrain.Runtime.MemoryOperationBindings

  test "recall callbacks bind runtime owners into the recall orchestrator" do
    test_pid = self()

    binding = %{
      snapshot_pin: fn request ->
        send(test_pid, {:binding_snapshot, request.tenant_ref})
        {:ok, ordering_evidence()}
      end,
      access_graph_views: fn context ->
        send(test_pid, {:binding_graph, context.snapshot_epoch})

        {:ok,
         %{
           authorized_agent_refs: ["agent://alpha"],
           shared_scope_refs: ["scope://team"],
           governed_policy_refs: ["promote-policy://stable"]
         }}
      end,
      read_policy: fn context ->
        send(test_pid, {:binding_policy, context.snapshot_epoch})
        {:ok, %{policy_ref: "read-policy://alpha"}}
      end,
      tier_reader: fn tier, context ->
        send(test_pid, {:binding_tier, tier, context.snapshot_epoch})
        {:ok, recall_fragments(tier)}
      end,
      transform: fn fragments, _context -> {:ok, fragments} end,
      recall_proof: fn context ->
        send(test_pid, {:binding_proof, context.snapshot_epoch})
        {:ok, %{proof_id: "proof://recall/bound", kind: :recall}}
      end
    }

    assert {:ok, callbacks} = MemoryOperationBindings.recall_callbacks(binding)
    assert {:ok, result} = RecallOrchestrator.recall(recall_request(), callbacks)

    assert result.proof_token.proof_id == "proof://recall/bound"
    assert_received {:binding_snapshot, "tenant://alpha"}
    assert_received {:binding_graph, 42}
    assert_received {:binding_policy, 42}
    assert_received {:binding_tier, :private, 42}
    assert_received {:binding_tier, :shared, 42}
    assert_received {:binding_tier, :governed, 42}
    assert_received {:binding_proof, 42}
  end

  test "private write callbacks bind runtime owners into the private writer" do
    binding = %{
      write_policy: fn _context -> {:ok, %{policy_ref: "write-policy://alpha"}} end,
      extract_candidates: fn _context ->
        {:ok,
         [
           %{
             candidate_id: "candidate-1",
             content: %{body: "memory"},
             source_lineage: %{semantic_output_ref: "semantic-output://1"}
           }
         ]}
      end,
      write_transform: fn candidates, _context -> {:ok, candidates} end,
      dedupe_private: fn candidates, _context -> {:ok, candidates} end,
      insert_private: fn fragment, _context ->
        {:ok, Map.put(fragment, :db_row_ref, "memory_private://row-1")}
      end,
      write_private_proof: fn context ->
        {:ok,
         %{
           proof_id: "proof://write-private/bound",
           kind: :write_private,
           fragment_ids: Enum.map(context.inserted_fragments, & &1.fragment_id)
         }}
      end
    }

    assert {:ok, callbacks} = MemoryOperationBindings.private_write_callbacks(binding)
    assert {:ok, result} = PrivateWriter.write_private(write_request(), callbacks)

    assert result.proof_token.proof_id == "proof://write-private/bound"
    assert [%{db_row_ref: "memory_private://row-1"}] = result.inserted_fragments
  end

  test "share-up callbacks bind runtime owners into the share-up client" do
    binding = %{
      scope_registered?: fn _context -> {:ok, true} end,
      share_up_policy: fn _context ->
        {:ok,
         %{
           policy_ref: "share-up-policy://runtime",
           transform_pipeline: [%{kind: :redact, fields: ["secret"]}]
         }}
      end,
      share_up_transform: fn fragment, _context -> {:ok, fragment} end,
      insert_shared: fn fragment, _context ->
        {:ok, Map.put(fragment, :db_row_ref, "memory_shared://row-1")}
      end,
      share_up_proof: fn context ->
        {:ok,
         %{
           proof_id: "proof://share-up/bound",
           kind: :share_up,
           fragment_id: context.shared_fragment.fragment_id
         }}
      end
    }

    assert {:ok, callbacks} = MemoryOperationBindings.share_up_callbacks(binding)
    assert {:ok, result} = ShareUpClient.share_up(share_up_request(), callbacks)

    assert result.shared_fragment.db_row_ref == "memory_shared://row-1"
    assert result.proof_token.proof_id == "proof://share-up/bound"
  end

  test "invalidation callbacks bind runtime owners for cluster fanout and durable reconciliation" do
    test_pid = self()

    binding = %{
      recall_cache_invalidate: fn invalidation ->
        send(test_pid, {:recall_cache_invalidated, invalidation.fragment_id})
        {:ok, %{evicted_entries: 1}}
      end,
      sidecar_index_invalidate: fn invalidation ->
        send(test_pid, {:sidecar_invalidated, invalidation.fragment_id})
        {:ok, %{evicted_entries: 1}}
      end,
      durable_invalidation_rows: fn opts ->
        send(test_pid, {:durable_reconcile, opts[:tenant_ref], opts[:after_epoch]})
        {:ok, [durable_invalidation("fragment-durable")]}
      end
    }

    assert {:ok, callbacks} = MemoryOperationBindings.invalidation_callbacks(binding)

    assert {:ok, %{recall_cache_evictions: 1, sidecar_index_evictions: 1}} =
             MemoryInvalidationConsumer.apply_cluster_message(
               cluster_message("fragment-cluster"),
               callbacks
             )

    assert_received {:recall_cache_invalidated, "fragment-cluster"}
    assert_received {:sidecar_invalidated, "fragment-cluster"}

    assert {:ok, %{rows_seen: 1, recall_cache_evictions: 1, sidecar_index_evictions: 1}} =
             MemoryInvalidationConsumer.reconcile_from_durable(callbacks,
               tenant_ref: "tenant://alpha",
               after_epoch: 43
             )

    assert_received {:durable_reconcile, "tenant://alpha", 43}
    assert_received {:recall_cache_invalidated, "fragment-durable"}
    assert_received {:sidecar_invalidated, "fragment-durable"}

    assert {:error, {:missing_ordering_evidence, :commit_lsn}} =
             MemoryInvalidationConsumer.apply_cluster_message(
               Map.delete(cluster_message("fragment-bad"), :commit_lsn),
               callbacks
             )
  end

  test "runtime binding validation fails closed on missing callback owners" do
    assert {:error, {:missing_binding, :recall_proof}} =
             MemoryOperationBindings.recall_callbacks(%{
               snapshot_pin: fn _request -> {:ok, ordering_evidence()} end,
               access_graph_views: fn _context -> {:ok, %{authorized_agent_refs: []}} end,
               read_policy: fn _context -> {:ok, %{}} end,
               tier_reader: fn _tier, _context -> {:ok, []} end,
               transform: fn fragments, _context -> {:ok, fragments} end
             })

    assert {:error, {:missing_binding, :write_private_proof}} =
             MemoryOperationBindings.private_write_callbacks(%{
               write_policy: fn _context -> {:ok, %{}} end,
               extract_candidates: fn _context -> {:ok, []} end,
               write_transform: fn candidates, _context -> {:ok, candidates} end,
               dedupe_private: fn candidates, _context -> {:ok, candidates} end,
               insert_private: fn fragment, _context -> {:ok, fragment} end
             })

    assert {:error, {:missing_binding, :share_up_proof}} =
             MemoryOperationBindings.share_up_callbacks(%{
               scope_registered?: fn _context -> {:ok, true} end,
               share_up_policy: fn _context -> {:ok, %{}} end,
               share_up_transform: fn fragment, _context -> {:ok, fragment} end,
               insert_shared: fn fragment, _context -> {:ok, fragment} end
             })

    assert {:error, {:missing_binding, :sidecar_index_invalidate}} =
             MemoryOperationBindings.invalidation_callbacks(%{
               recall_cache_invalidate: fn _invalidation -> {:ok, %{evicted_entries: 0}} end,
               durable_invalidation_rows: fn _opts -> {:ok, []} end
             })
  end

  defp recall_request do
    %{
      tenant_ref: "tenant://alpha",
      user_ref: "user://alpha",
      agent_ref: "agent://alpha",
      trace_id: "trace-recall-alpha",
      source_node_ref: "node://memory-reader@host/reader-1",
      top_k_by_tier: %{private: 1, shared: 1, governed: 1}
    }
  end

  defp write_request do
    %{
      tenant_ref: "tenant://alpha",
      user_ref: "user://alpha",
      agent_ref: "agent://alpha",
      trace_id: "trace-write-alpha",
      semantic_output_ref: "semantic-output://1",
      semantic_output: %{facts: ["memory"]},
      source_node_ref: "node://memory-writer@host/writer-1",
      commit_lsn: "16/B374D849",
      commit_hlc: %{wall_ns: 1_800_000_000_000_000_100, logical: 2, node: "writer-1"},
      effective_access: %{user_refs: ["user://alpha"], agent_refs: ["agent://alpha"]}
    }
  end

  defp share_up_request do
    %{
      tenant_ref: "tenant://alpha",
      user_ref: "user://alpha",
      agent_ref: "agent://alpha",
      trace_id: "trace-share-up-alpha",
      snapshot_epoch: 42,
      target_scope_ref: "scope://team",
      source_node_ref: "node://memory-writer@host/writer-1",
      commit_lsn: "16/B374D84A",
      commit_hlc: %{wall_ns: 1_800_000_000_000_000_200, logical: 3, node: "writer-1"},
      private_fragment: %{
        fragment_id: "private-1",
        tier: :private,
        user_ref: "user://alpha",
        source_node_ref: "node://memory-writer@host/writer-0",
        source_agents: ["agent://alpha"],
        source_resources: ["resource://doc"],
        source_scopes: [],
        access_agents: ["agent://alpha"],
        access_resources: ["resource://doc"],
        access_scopes: [],
        content: %{body: "memory"},
        content_hash: "sha256:private",
        content_ref: %{uri: "memory_private://row"},
        schema_ref: "schema://memory/private"
      }
    }
  end

  defp ordering_evidence do
    %{
      snapshot_epoch: 42,
      source_node_ref: "node://memory-reader@host/reader-1",
      commit_lsn: "16/B374D848",
      commit_hlc: %{wall_ns: 1_800_000_000_000_000_000, logical: 1, node: "reader-1"}
    }
  end

  defp cluster_message(fragment_id) do
    %{
      tenant_ref: "tenant://alpha",
      source_node_ref: "node://outer-brain/peer-a",
      commit_lsn: "16/B374D848",
      commit_hlc: %{"w" => 1_800_000_000_000_000_000, "l" => 1, "n" => "peer-a"},
      metadata: %{
        "tenant_ref" => "tenant://alpha",
        "fragment_id" => fragment_id,
        "effective_at_epoch" => 44,
        "parent_chain" => []
      }
    }
  end

  defp durable_invalidation(fragment_id) do
    %{
      tenant_ref: "tenant://alpha",
      fragment_id: fragment_id,
      effective_at_epoch: 44,
      source_node_ref: "node://outer-brain/peer-a",
      commit_lsn: "16/B374D848",
      commit_hlc: %{"w" => 1_800_000_000_000_000_000, "l" => 1, "n" => "peer-a"}
    }
  end

  defp recall_fragments(:private) do
    [
      %{
        fragment_id: "private-1",
        tier: :private,
        user_ref: "user://alpha",
        access: %{user_refs: ["user://alpha"], agent_refs: ["agent://alpha"]},
        score: 1.0
      }
    ]
  end

  defp recall_fragments(:shared) do
    [
      %{
        fragment_id: "shared-1",
        tier: :shared,
        scope_refs: ["scope://team"],
        access: %{scope_refs: ["scope://team"], agent_refs: ["agent://alpha"]},
        score: 0.8
      }
    ]
  end

  defp recall_fragments(:governed) do
    [
      %{
        fragment_id: "governed-1",
        tier: :governed,
        access: %{agent_refs: ["agent://alpha"], governance_valid?: true},
        promote_policy_ref: "promote-policy://stable",
        score: 0.7
      }
    ]
  end
end
