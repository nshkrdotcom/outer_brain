defmodule OuterBrain.RestartAuthority.Reconcile do
  @moduledoc """
  Small helpers for creating recovery intents after restart analysis.
  """

  @spec recovery_intent(map()) :: {:ok, atom()} | {:error, :unknown_action}
  def recovery_intent(%{next_action: {action, detail}})
      when action in [:reconcile, :await_or_follow_up, :publish_or_dispatch, :noop] do
    {:ok, detail}
  end

  def recovery_intent(_analysis), do: {:error, :unknown_action}
end
