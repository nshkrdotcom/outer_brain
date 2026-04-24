defmodule OuterBrain.Memory.ShareUpClientTest do
  use ExUnit.Case, async: true

  alias OuterBrain.Memory.ShareUpClient

  test "share-up checks registry, applies non-identity transform, inserts shared fragment, and emits proof" do
    test_pid = self()

    callbacks = [
      scope_registered?: fn context ->
        send(test_pid, {:scope_check, context.request.target_scope_ref, context.snapshot_epoch})
        {:ok, true}
      end,
      share_up_policy: fn context ->
        send(test_pid, {:policy, context.request.tenant_ref})

        {:ok,
         %{
           policy_ref: "share-up-policy://team-alpha",
           transform_pipeline: [%{kind: :redact, fields: ["private_notes"]}],
           access_projection_rule: %{mode: :target_scope_only}
         }}
      end,
      transform: fn fragment, context ->
        send(test_pid, {:transform, context.share_up_policy.policy_ref})
        {:ok, Map.put(fragment, :content, %{body: "launch summary"})}
      end,
      insert_shared: fn shared_fragment, context ->
        send(
          test_pid,
          {:insert, shared_fragment.parent_fragment_id, context.request.target_scope_ref}
        )

        assert shared_fragment.tier == :shared
        assert shared_fragment.scope_ref == "scope://team-alpha"
        assert shared_fragment.parent_fragment_id == "fragment://private-alpha"
        assert shared_fragment.share_up_policy_ref == "share-up-policy://team-alpha"
        assert shared_fragment.transform_pipeline == [%{kind: :redact, fields: ["private_notes"]}]
        assert shared_fragment.non_identity_transform_count == 1
        assert shared_fragment.source_node_ref == context.request.source_node_ref
        assert shared_fragment.provenance.parent_source_node_ref == "node://outer/private-writer"
        assert shared_fragment.provenance.source_lineage.user_ref == "user://alpha"
        assert shared_fragment.provenance.effective_access.scope_refs == ["scope://team-alpha"]

        {:ok, Map.put(shared_fragment, :db_row_ref, "memory_shared://row-1")}
      end,
      proof_emitter: fn context ->
        send(test_pid, {:proof, context.shared_fragment.db_row_ref})

        {:ok,
         %{
           proof_id: "proof://share-up/alpha",
           kind: :share_up,
           source_node_ref: context.request.source_node_ref,
           commit_lsn: context.request.commit_lsn,
           commit_hlc: context.request.commit_hlc,
           snapshot_epoch: context.snapshot_epoch
         }}
      end
    ]

    assert {:ok, result} = ShareUpClient.share_up(share_up_request(), callbacks)

    assert result.shared_fragment.db_row_ref == "memory_shared://row-1"
    assert result.proof_token.proof_id == "proof://share-up/alpha"

    assert_received {:scope_check, "scope://team-alpha", 42}
    assert_received {:policy, "tenant://alpha"}
    assert_received {:transform, "share-up-policy://team-alpha"}
    assert_received {:insert, "fragment://private-alpha", "scope://team-alpha"}
    assert_received {:proof, "memory_shared://row-1"}
  end

  test "unregistered target scope fails closed before transform, insert, or proof" do
    test_pid = self()

    callbacks = [
      scope_registered?: fn _context -> {:ok, false} end,
      transform: fn _fragment, _context ->
        send(test_pid, :unexpected_transform)
        {:ok, %{}}
      end,
      insert_shared: fn _fragment, _context ->
        send(test_pid, :unexpected_insert)
        {:ok, %{}}
      end,
      proof_emitter: fn _context ->
        send(test_pid, :unexpected_proof)
        {:ok, %{}}
      end
    ]

    assert {:error, {:unregistered_shared_scope, "scope://team-alpha"}} =
             ShareUpClient.share_up(share_up_request(), callbacks)

    refute_received :unexpected_transform
    refute_received :unexpected_insert
    refute_received :unexpected_proof
  end

  test "identity-only share-up policy is rejected" do
    callbacks = [
      scope_registered?: fn _context -> {:ok, true} end,
      share_up_policy: fn _context ->
        {:ok,
         %{
           policy_ref: "share-up-policy://identity",
           transform_pipeline: [%{kind: :identity}]
         }}
      end
    ]

    assert {:error, {:identity_share_up_rejected, "share-up-policy://identity"}} =
             ShareUpClient.share_up(share_up_request(), callbacks)
  end

  test "user cannot share up another user's private fragment" do
    request =
      share_up_request()
      |> put_in([:private_fragment, :user_ref], "user://other")

    assert {:error, {:unauthorized_user, "user://alpha"}} =
             ShareUpClient.share_up(request, scope_registered?: fn _context -> {:ok, true} end)
  end

  defp share_up_request do
    %{
      tenant_ref: "tenant://alpha",
      user_ref: "user://alpha",
      agent_ref: "agent://alpha",
      trace_id: "trace-share-up-alpha",
      snapshot_epoch: 42,
      target_scope_ref: "scope://team-alpha",
      source_node_ref: "node://outer/share-up",
      commit_lsn: "16/B374D84A",
      commit_hlc: %{wall_ns: 1_800_000_000_000_000_200, logical: 3, node: "share-up"},
      private_fragment: %{
        fragment_id: "fragment://private-alpha",
        tier: :private,
        user_ref: "user://alpha",
        source_node_ref: "node://outer/private-writer",
        source_agents: ["agent://alpha"],
        source_resources: ["resource://doc-a"],
        source_scopes: [],
        access_agents: ["agent://alpha"],
        access_resources: ["resource://doc-a"],
        access_scopes: [],
        content: %{body: "launch summary with private_notes"},
        content_hash: "sha256:private",
        content_ref: %{uri: "memory_private://fragment-alpha"},
        schema_ref: "schema://memory/private",
        metadata: %{source: "test"}
      }
    }
  end
end
