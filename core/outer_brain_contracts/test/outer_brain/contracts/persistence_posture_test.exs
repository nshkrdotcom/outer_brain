defmodule OuterBrain.Contracts.PersistencePostureTest do
  use ExUnit.Case, async: true

  alias OuterBrain.Contracts.PersistencePosture

  test "memory posture is ref-only and non-durable" do
    posture = PersistencePosture.memory(:semantic_session)

    assert posture.persistence_profile_ref == "persistence-profile://mickey-mouse"
    assert posture.store_set_ref == "store-set://outer-brain/memory-ref-only"
    assert posture.durable? == false
    assert posture.raw_prompt_persistence? == false
    assert posture.raw_provider_payload_persistence? == false
  end

  test "durable posture adds durable refs without raw prompt persistence" do
    posture = PersistencePosture.durable(:prompt_provenance)

    assert posture.durable? == true
    assert posture.persistence_tier_ref == "persistence-tier://durable"
    assert posture.raw_prompt_persistence? == false
    assert posture.raw_provider_payload_persistence? == false
  end

  test "debug tap failure is non-mutating evidence" do
    posture =
      :journal
      |> PersistencePosture.memory()
      |> PersistencePosture.debug_tap_failed()

    assert posture.debug_tap_result == :failed_non_mutating
    assert posture.debug_sidecar_mutated_state? == false
    assert posture.persistence_profile_ref == "persistence-profile://mickey-mouse"
  end
end
