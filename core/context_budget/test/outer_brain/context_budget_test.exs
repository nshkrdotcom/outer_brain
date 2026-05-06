defmodule OuterBrain.ContextBudgetTest do
  use ExUnit.Case, async: true

  alias OuterBrain.ContextBudget

  test "budget decisions consume residual deterministically" do
    assert {:ok, bucket} = ContextBudget.token_bucket("budget://tokens", 10, 2)
    assert ContextBudget.residual(bucket) == 8

    assert {:ok, updated, decision} = ContextBudget.decide(bucket, 3)
    assert decision.decision == :allow
    assert decision.residual_units == 5
    assert ContextBudget.residual(updated) == 5
  end

  test "budget exhaustion fails closed" do
    assert {:ok, bucket} = ContextBudget.byte_bucket("budget://bytes", 5)
    assert {:ok, ^bucket, decision} = ContextBudget.decide(bucket, 8)
    assert decision.decision == :deny_exhausted
    assert decision.reason == :cumulative_overflow
  end

  test "child budgets cannot exceed parent residual" do
    assert {:ok, parent} = ContextBudget.turn_bucket("budget://turns", 4, 1)
    assert {:ok, updated_parent, child} = ContextBudget.compose(parent, 2)
    assert ContextBudget.residual(updated_parent) == 1
    assert child.limit == 2

    assert {:error, :child_budget_exceeds_parent_residual} =
             ContextBudget.compose(updated_parent, 2)
  end

  test "operator override requires permission and bounded duration" do
    assert {:ok, bucket} = ContextBudget.token_bucket("budget://tokens", 1)

    assert {:error, :missing_budget_override_permission} =
             ContextBudget.override(bucket, 1, %{
               permission_ref: "permission://budget/read",
               reason_ref: "decision://operator",
               duration_seconds: 60
             })

    assert {:error, :budget_override_duration_unbounded} =
             ContextBudget.override(bucket, 1, %{
               permission_ref: "permission://budget/override",
               reason_ref: "decision://operator",
               duration_seconds: 3601
             })

    assert {:ok, overridden} =
             ContextBudget.override(bucket, 1, %{
               permission_ref: "permission://budget/override",
               reason_ref: "decision://operator",
               duration_seconds: 60
             })

    assert overridden.limit == 2
  end
end
