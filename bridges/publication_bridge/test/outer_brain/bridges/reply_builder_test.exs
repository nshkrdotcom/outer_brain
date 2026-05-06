defmodule OuterBrain.Bridges.ReplyBuilderTest do
  use ExUnit.Case, async: true

  alias OuterBrain.Bridges.ReplyBuilder

  test "provisional and final reply publications stay distinct" do
    assert {:ok, provisional, provisional_row} =
             ReplyBuilder.provisional("causal_1", "Working on it", "causal_1:provisional")

    assert {:ok, final, final_row} =
             ReplyBuilder.final("causal_1", "Done", "causal_1:final")

    assert provisional.phase == :provisional
    assert final.phase == :final
    assert provisional_row.phase == :provisional
    assert final_row.phase == :final
  end

  test "large reply bodies become bounded redacted previews plus artifact refs" do
    body =
      "token=super-secret " <>
        String.duplicate("semantic reply body that should not stay fully inline ", 200)

    assert {:ok, publication, row} =
             ReplyBuilder.final("causal_large", body, "causal_large:final")

    refute publication.body == body
    refute row.body == body
    assert byte_size(publication.body) <= ReplyBuilder.max_inline_body_preview_bytes()
    assert publication.body == row.body
    assert String.contains?(publication.body, "[REDACTED]")
    assert publication.body_ref == row.body_ref
    assert publication.body_ref["content_hash"] == publication.body_ref["body_hash"]
    assert publication.body_ref["schema_hash_alg"] == "sha256"
    assert String.contains?(publication.body_ref["redaction_manifest_ref"], "sha256:")
    assert publication.body_ref["causal_unit_id"] == "causal_large"
    assert publication.body_ref["phase"] == "final"
    assert publication.body_ref["dedupe_key"] == "causal_large:final"
    assert publication.body_ref["existing_fetch_or_restore_path"] == "unavailable_fail_closed"
  end
end
