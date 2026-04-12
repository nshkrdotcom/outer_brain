defmodule OuterBrain.Contracts.RuntimeFact do
  @moduledoc """
  Durable lower-runtime fact consumed by the semantic layer.
  """

  @kinds [
    :accepted_downstream,
    :execution_completed,
    :publication_failed,
    :pressure,
    :reconnect,
    :lane_churn
  ]

  defstruct [:fact_id, :kind, :causal_unit_id, payload: %{}]

  @type kind ::
          :accepted_downstream
          | :execution_completed
          | :publication_failed
          | :pressure
          | :reconnect
          | :lane_churn

  @type t :: %__MODULE__{
          fact_id: String.t(),
          kind: kind(),
          causal_unit_id: String.t(),
          payload: map()
        }

  @spec kinds() :: [kind()]
  def kinds, do: @kinds

  @spec new(map()) :: {:ok, t()} | {:error, term()}
  def new(%{fact_id: fact_id, kind: kind, causal_unit_id: causal_unit_id, payload: payload})
      when is_binary(fact_id) and kind in @kinds and is_binary(causal_unit_id) and is_map(payload) do
    {:ok,
     %__MODULE__{fact_id: fact_id, kind: kind, causal_unit_id: causal_unit_id, payload: payload}}
  end

  def new(_attrs), do: {:error, :invalid_runtime_fact}

  @spec wake_key(t()) :: String.t()
  def wake_key(%__MODULE__{causal_unit_id: causal_unit_id, kind: kind}) do
    "#{causal_unit_id}:#{kind}"
  end
end
