defmodule OuterBrain.Contracts.Lease do
  @moduledoc """
  Lease contract for one semantic-session owner.
  """

  alias OuterBrain.Contracts.PersistencePosture

  defstruct [
    :session_id,
    :holder,
    :lease_id,
    :epoch,
    :expires_at,
    persistence_posture: PersistencePosture.memory(:semantic_session)
  ]

  @type t :: %__MODULE__{
          session_id: String.t(),
          holder: String.t(),
          lease_id: String.t(),
          epoch: non_neg_integer(),
          expires_at: DateTime.t(),
          persistence_posture: PersistencePosture.t()
        }

  @required_fields [:session_id, :holder, :lease_id, :epoch, :expires_at]

  @spec new(map()) :: {:ok, t()} | {:error, term()}
  def new(attrs) when is_map(attrs) do
    with :ok <- ensure_required_fields(attrs),
         {:ok, epoch} <- fetch_non_negative_integer(attrs, :epoch),
         {:ok, expires_at} <- fetch_datetime(attrs, :expires_at) do
      {:ok,
       %__MODULE__{
         session_id: Map.fetch!(attrs, :session_id),
         holder: Map.fetch!(attrs, :holder),
         lease_id: Map.fetch!(attrs, :lease_id),
         epoch: epoch,
         expires_at: expires_at,
         persistence_posture: PersistencePosture.resolve(:semantic_session, attrs)
       }}
    end
  end

  @spec expired?(t(), DateTime.t()) :: boolean()
  def expired?(%__MODULE__{expires_at: expires_at}, %DateTime{} = now) do
    DateTime.compare(expires_at, now) != :gt
  end

  defp ensure_required_fields(attrs) do
    missing =
      Enum.reject(@required_fields, fn field ->
        Map.has_key?(attrs, field)
      end)

    case missing do
      [] -> :ok
      _ -> {:error, {:missing_fields, missing}}
    end
  end

  defp fetch_non_negative_integer(attrs, field) do
    case Map.fetch!(attrs, field) do
      value when is_integer(value) and value >= 0 -> {:ok, value}
      _ -> {:error, {:invalid_non_negative_integer, field}}
    end
  end

  defp fetch_datetime(attrs, field) do
    case Map.fetch!(attrs, field) do
      %DateTime{} = value -> {:ok, value}
      _ -> {:error, {:invalid_datetime, field}}
    end
  end
end
