defmodule OuterBrain.ContextBudget do
  @moduledoc """
  Deterministic token, byte, and turn budget accounting.
  """

  alias OuterBrain.MemoryContracts

  defmodule Bucket do
    @moduledoc "One bounded budget bucket."
    @enforce_keys [:budget_ref, :kind, :limit, :used]
    defstruct @enforce_keys

    @type t :: %__MODULE__{
            budget_ref: String.t(),
            kind: atom(),
            limit: non_neg_integer(),
            used: non_neg_integer()
          }
  end

  @kinds [:token, :byte, :turn]

  @type bucket :: Bucket.t()

  @spec token_bucket(String.t(), non_neg_integer(), non_neg_integer()) ::
          {:ok, bucket()} | {:error, term()}
  def token_bucket(budget_ref, limit, used \\ 0), do: bucket(:token, budget_ref, limit, used)

  @spec byte_bucket(String.t(), non_neg_integer(), non_neg_integer()) ::
          {:ok, bucket()} | {:error, term()}
  def byte_bucket(budget_ref, limit, used \\ 0), do: bucket(:byte, budget_ref, limit, used)

  @spec turn_bucket(String.t(), non_neg_integer(), non_neg_integer()) ::
          {:ok, bucket()} | {:error, term()}
  def turn_bucket(budget_ref, limit, used \\ 0), do: bucket(:turn, budget_ref, limit, used)

  @spec residual(bucket()) :: non_neg_integer()
  def residual(%Bucket{limit: limit, used: used}) when limit >= used, do: limit - used
  def residual(%Bucket{}), do: 0

  @spec decide(bucket(), non_neg_integer(), keyword()) ::
          {:ok, bucket(), MemoryContracts.ContextBudgetDecision.t()} | {:error, term()}
  def decide(bucket, requested_units, opts \\ [])

  def decide(%Bucket{} = bucket, requested_units, opts)
      when is_integer(requested_units) and requested_units >= 0 and is_list(opts) do
    policy = Keyword.get(opts, :policy, :allow)

    cond do
      policy == :deny ->
        denied(bucket, requested_units, :deny_policy, :policy_denial)

      requested_units > residual(bucket) ->
        denied(bucket, requested_units, :deny_exhausted, :cumulative_overflow)

      true ->
        granted = requested_units
        updated = %Bucket{bucket | used: bucket.used + granted}

        with {:ok, decision} <-
               MemoryContracts.budget_decision(%{
                 budget_ref: bucket.budget_ref,
                 decision: :allow,
                 requested_units: requested_units,
                 granted_units: granted,
                 residual_units: residual(updated)
               }) do
          {:ok, updated, decision}
        end
    end
  end

  def decide(%Bucket{}, _requested_units, _opts), do: {:error, :invalid_requested_units}

  @spec compose(bucket(), non_neg_integer()) :: {:ok, bucket(), bucket()} | {:error, term()}
  def compose(%Bucket{} = parent, child_limit)
      when is_integer(child_limit) and child_limit >= 0 do
    if child_limit <= residual(parent) do
      child = %Bucket{
        budget_ref: parent.budget_ref <> "/child",
        kind: parent.kind,
        limit: child_limit,
        used: 0
      }

      updated_parent = %Bucket{parent | used: parent.used + child_limit}
      {:ok, updated_parent, child}
    else
      {:error, :child_budget_exceeds_parent_residual}
    end
  end

  def compose(%Bucket{}, _child_limit), do: {:error, :invalid_child_budget}

  @spec override(bucket(), non_neg_integer(), map()) :: {:ok, bucket()} | {:error, term()}
  def override(%Bucket{} = bucket, added_units, attrs)
      when is_integer(added_units) and added_units > 0 and is_map(attrs) do
    with {:ok, permission_ref} <- required_string(attrs, :permission_ref),
         {:ok, reason_ref} <- required_string(attrs, :reason_ref),
         {:ok, duration_seconds} <- required_positive_integer(attrs, :duration_seconds),
         :ok <- allowed_permission(permission_ref),
         :ok <- bounded_duration(duration_seconds) do
      _reason_ref = reason_ref
      {:ok, %Bucket{bucket | limit: bucket.limit + added_units}}
    end
  end

  def override(%Bucket{}, _added_units, _attrs), do: {:error, :invalid_budget_override}

  defp bucket(kind, budget_ref, limit, used)
       when kind in @kinds and is_binary(budget_ref) and is_integer(limit) and is_integer(used) and
              limit >= 0 and used >= 0 and used <= limit do
    {:ok, %Bucket{budget_ref: budget_ref, kind: kind, limit: limit, used: used}}
  end

  defp bucket(_kind, _budget_ref, _limit, _used), do: {:error, :invalid_budget_bucket}

  defp denied(bucket, requested_units, decision, reason) do
    with {:ok, budget_decision} <-
           MemoryContracts.budget_decision(%{
             budget_ref: bucket.budget_ref,
             decision: decision,
             reason: reason,
             requested_units: requested_units,
             granted_units: 0,
             residual_units: residual(bucket)
           }) do
      {:ok, bucket, budget_decision}
    end
  end

  defp allowed_permission("permission://budget/override"), do: :ok
  defp allowed_permission(_permission_ref), do: {:error, :missing_budget_override_permission}

  defp bounded_duration(duration_seconds) when duration_seconds <= 3600, do: :ok
  defp bounded_duration(_duration_seconds), do: {:error, :budget_override_duration_unbounded}

  defp required_string(attrs, field) do
    case Map.get(attrs, field) || Map.get(attrs, Atom.to_string(field)) do
      value when is_binary(value) ->
        if String.trim(value) == "", do: {:error, {:missing_field, field}}, else: {:ok, value}

      _other ->
        {:error, {:missing_field, field}}
    end
  end

  defp required_positive_integer(attrs, field) do
    case Map.get(attrs, field) || Map.get(attrs, Atom.to_string(field)) do
      value when is_integer(value) and value > 0 -> {:ok, value}
      _other -> {:error, {:invalid_field, field}}
    end
  end
end
