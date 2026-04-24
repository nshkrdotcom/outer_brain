defmodule OuterBrain.Memory.PrivateWriterTest do
  use ExUnit.Case, async: true

  alias OuterBrain.Memory.PrivateWriter

  test "private write resolves policy, transforms candidates, seals provenance, inserts, and emits proof" do
    test_pid = self()

    callbacks = [
      write_policy: fn context ->
        send(test_pid, {:write_policy, context.request.tenant_ref})

        {:ok,
         %{policy_ref: "write-policy://private-alpha", transform_policy: %{mode: :summarize}}}
      end,
      extract_candidates: fn context ->
        send(test_pid, {:extract, context.request.semantic_output_ref})

        {:ok,
         [
           %{
             candidate_id: "candidate-1",
             content: %{body: "remember the launch decision"},
             source_lineage: %{semantic_output_ref: context.request.semantic_output_ref}
           }
         ]}
      end,
      transform: fn candidates, context ->
        send(test_pid, {:transform, context.write_policy.policy_ref})

        {:ok,
         Enum.map(candidates, fn candidate ->
           Map.put(candidate, :content, %{body: "launch decision", redacted?: true})
         end)}
      end,
      dedupe: fn candidates, context ->
        send(test_pid, {:dedupe, context.request.user_ref})
        {:ok, candidates}
      end,
      insert_private: fn fragment, context ->
        send(test_pid, {:insert, fragment.fragment_id, context.request.tenant_ref})

        assert fragment.tier == :private
        assert fragment.provenance.source_node_ref == context.request.source_node_ref
        assert fragment.provenance.commit_lsn == context.request.commit_lsn
        assert fragment.provenance.commit_hlc == context.request.commit_hlc
        assert fragment.provenance.effective_access == context.request.effective_access
        assert fragment.provenance.source_lineage.semantic_output_ref == "semantic-output://1"
        assert fragment.provenance.write_policy_ref == "write-policy://private-alpha"

        {:ok, Map.put(fragment, :db_row_ref, "memory_private://row-1")}
      end,
      proof_emitter: fn context ->
        send(test_pid, {:proof, Enum.map(context.inserted_fragments, & &1.db_row_ref)})

        {:ok,
         %{
           proof_id: "proof://write-private/alpha",
           kind: :write_private,
           source_node_ref: context.request.source_node_ref,
           commit_lsn: context.request.commit_lsn,
           commit_hlc: context.request.commit_hlc,
           fragment_ids: Enum.map(context.inserted_fragments, & &1.fragment_id)
         }}
      end
    ]

    assert {:ok, result} = PrivateWriter.write_private(write_request(), callbacks)

    assert [%{db_row_ref: "memory_private://row-1"}] = result.inserted_fragments
    assert result.proof_token.proof_id == "proof://write-private/alpha"

    assert_received {:write_policy, "tenant://alpha"}
    assert_received {:extract, "semantic-output://1"}
    assert_received {:transform, "write-policy://private-alpha"}
    assert_received {:dedupe, "user://alpha"}
    assert_received {:insert, "candidate-1", "tenant://alpha"}
    assert_received {:proof, ["memory_private://row-1"]}
  end

  test "missing node or ordering evidence fails before insert or proof emission" do
    test_pid = self()

    callbacks = [
      insert_private: fn _fragment, _context ->
        send(test_pid, :unexpected_insert)
        {:ok, %{}}
      end,
      proof_emitter: fn _context ->
        send(test_pid, :unexpected_proof)
        {:ok, %{}}
      end
    ]

    request = Map.delete(write_request(), :commit_hlc)

    assert {:error, {:missing_ordering_evidence, :commit_hlc}} =
             PrivateWriter.write_private(request, callbacks)

    refute_received :unexpected_insert
    refute_received :unexpected_proof
  end

  defp write_request do
    %{
      tenant_ref: "tenant://alpha",
      user_ref: "user://alpha",
      agent_ref: "agent://alpha",
      trace_id: "trace-write-alpha",
      semantic_output_ref: "semantic-output://1",
      semantic_output: %{facts: ["remember the launch decision"]},
      source_node_ref: "node://memory-writer@host/writer-1",
      commit_lsn: "16/B374D849",
      commit_hlc: %{wall_ns: 1_800_000_000_000_000_100, logical: 2, node: "writer-1"},
      effective_access: %{
        user_refs: ["user://alpha"],
        agent_refs: ["agent://alpha"],
        scope_refs: []
      }
    }
  end
end
