defmodule OuterBrain.Core.RuntimeFactNormalizer do
  @moduledoc """
  Normalizes lower-runtime facts into one semantic wake path.
  """

  alias OuterBrain.Contracts.RuntimeFact

  @wake_paths %{
    accepted_downstream: :observe_progress,
    execution_completed: :re_deliberate,
    publication_failed: :repair_publication,
    pressure: :slow_down,
    reconnect: :refresh_stream,
    lane_churn: :reconcile_lane
  }

  @spec normalize(RuntimeFact.t()) :: %{
          fact_id: String.t(),
          wake_path: atom(),
          causal_unit_id: String.t()
        }
  def normalize(%RuntimeFact{} = fact) do
    %{
      fact_id: fact.fact_id,
      wake_path: Map.fetch!(@wake_paths, fact.kind),
      causal_unit_id: fact.causal_unit_id
    }
  end
end
