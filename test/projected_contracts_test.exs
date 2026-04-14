defmodule OuterBrain.ProjectedContractsTest do
  use ExUnit.Case, async: true

  alias OuterBrain.Contracts.ReplyPublication

  test "projected contract artifact exposes reply publication phases" do
    assert ReplyPublication.valid_phase?(:provisional)
    assert ReplyPublication.valid_phase?(:final)
  end
end
