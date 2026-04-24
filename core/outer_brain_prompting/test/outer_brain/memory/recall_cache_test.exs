defmodule OuterBrain.Memory.RecallCacheTest do
  use ExUnit.Case, async: true

  alias OuterBrain.Memory.{RecallCache, SidecarIndex}

  test "recall cache stores fragment ids and hashes only and evicts by cluster or durable invalidation" do
    cache = RecallCache.new()

    old_key = cache_key(snapshot_epoch: 43)
    current_key = cache_key(snapshot_epoch: 44)

    assert :ok = RecallCache.put(cache, old_key, [fragment_ref("fragment-1")])
    assert :ok = RecallCache.put(cache, current_key, [fragment_ref("fragment-1")])

    assert {:error, {:unsafe_cache_payload, :content}} =
             RecallCache.put(cache, cache_key(snapshot_epoch: 45), [
               Map.put(fragment_ref("fragment-unsafe"), :content, %{body: "do not cache"})
             ])

    assert {:ok, [%{fragment_id: "fragment-1"} = cached]} = RecallCache.fetch(cache, current_key)
    refute Map.has_key?(cached, :content)

    assert {:ok, %{evicted_entries: 1}} =
             RecallCache.apply_cluster_invalidation(
               cache,
               cluster_message("fragment-1", effective_at_epoch: 44)
             )

    assert {:ok, [%{fragment_id: "fragment-1"}]} = RecallCache.fetch(cache, old_key)
    assert :miss = RecallCache.fetch(cache, current_key)

    assert :ok = RecallCache.put(cache, current_key, [fragment_ref("fragment-2")])

    assert {:ok, %{evicted_entries: 1}} =
             RecallCache.reconcile(cache, [
               durable_invalidation("fragment-2", effective_at_epoch: 44)
             ])

    assert :miss = RecallCache.fetch(cache, current_key)
  end

  test "sidecar index evicts entries that reference invalidated fragments" do
    index = SidecarIndex.new()

    old_key = sidecar_key(snapshot_epoch: 43)
    current_key = sidecar_key(snapshot_epoch: 44)

    assert :ok = SidecarIndex.put(index, old_key, [fragment_ref("fragment-1")])
    assert :ok = SidecarIndex.put(index, current_key, [fragment_ref("fragment-1")])

    assert {:ok, %{evicted_entries: 1}} =
             SidecarIndex.apply_cluster_invalidation(
               index,
               cluster_message("fragment-1", effective_at_epoch: 44)
             )

    assert {:ok, [%{fragment_id: "fragment-1"}]} = SidecarIndex.fetch(index, old_key)
    assert :miss = SidecarIndex.fetch(index, current_key)

    assert :ok = SidecarIndex.put(index, current_key, [fragment_ref("fragment-2")])

    assert {:ok, %{evicted_entries: 1}} =
             SidecarIndex.reconcile(index, [
               durable_invalidation("fragment-2", effective_at_epoch: 44)
             ])

    assert :miss = SidecarIndex.fetch(index, current_key)
  end

  defp cache_key(overrides) do
    Keyword.merge(
      [
        tenant_ref: "tenant://alpha",
        snapshot_epoch: 44,
        tier: :private,
        query_hash: "sha256:query-alpha"
      ],
      overrides
    )
    |> Map.new()
  end

  defp sidecar_key(overrides) do
    Keyword.merge(
      [
        tenant_ref: "tenant://alpha",
        snapshot_epoch: 44,
        sidecar_ref: "sidecar://recall/alpha"
      ],
      overrides
    )
    |> Map.new()
  end

  defp fragment_ref(fragment_id) do
    %{
      fragment_id: fragment_id,
      tier: :private,
      content_hash: "sha256:#{fragment_id}"
    }
  end

  defp cluster_message(fragment_id, overrides) do
    metadata =
      %{
        "fragment_id" => fragment_id,
        "tenant_ref" => "tenant://alpha",
        "effective_at_epoch" => Keyword.fetch!(overrides, :effective_at_epoch),
        "parent_chain" => []
      }

    %{
      tenant_ref: "tenant://alpha",
      source_node_ref: "node://outer-brain/peer-a",
      commit_lsn: "16/B374D848",
      commit_hlc: %{"w" => 1_800_000_000_000_000_000, "l" => 1, "n" => "peer-a"},
      metadata: metadata
    }
  end

  defp durable_invalidation(fragment_id, overrides) do
    %{
      tenant_ref: "tenant://alpha",
      fragment_id: fragment_id,
      effective_at_epoch: Keyword.fetch!(overrides, :effective_at_epoch),
      source_node_ref: "node://outer-brain/peer-a",
      commit_lsn: "16/B374D848",
      commit_hlc: %{"w" => 1_800_000_000_000_000_000, "l" => 1, "n" => "peer-a"}
    }
  end
end
