defmodule OuterBrain.Journal do
  @moduledoc """
  In-memory journal state and transaction helpers used to prove semantic-runtime
  recovery semantics without requiring process-local state.
  """

  alias OuterBrain.Journal.Tables.{
    ContextPackRecord,
    QualityCheckpointRecord,
    RecoveryTaskRecord,
    ReplyPublicationRecord,
    SemanticFrameRecord,
    SemanticJournalEntryRecord,
    SemanticSessionLeaseRecord,
    StrategyProfileRecord,
    ToolManifestRecord
  }

  @type table ::
          :semantic_session_leases
          | :semantic_journal_entries
          | :semantic_frames
          | :context_packs
          | :strategy_profiles
          | :tool_manifests
          | :quality_checkpoints
          | :reply_publications
          | :recovery_tasks

  @type state :: %{required(table()) => %{optional(String.t()) => struct()}}

  @tables [
    :semantic_session_leases,
    :semantic_journal_entries,
    :semantic_frames,
    :context_packs,
    :strategy_profiles,
    :tool_manifests,
    :quality_checkpoints,
    :reply_publications,
    :recovery_tasks
  ]

  @spec new() :: state()
  def new do
    Map.new(@tables, fn table -> {table, %{}} end)
  end

  @spec transact(state(), (state() -> {:ok, [tuple()], term()} | {:error, term()})) ::
          {:ok, state(), term()} | {:error, term()}
  def transact(state, fun) when is_function(fun, 1) do
    with {:ok, ops, result} <- fun.(state) do
      {:ok, apply_ops(state, ops), result}
    end
  end

  @spec insert(table(), struct()) :: tuple()
  def insert(table, row), do: {:insert, table, record_id(table, row), row}

  @spec all(state(), table()) :: [struct()]
  def all(state, table) do
    state |> Map.fetch!(table) |> Map.values()
  end

  @spec fetch(state(), table(), String.t()) :: {:ok, struct()} | :error
  def fetch(state, table, id) do
    case get_in(state, [table, id]) do
      nil -> :error
      row -> {:ok, row}
    end
  end

  @spec latest_publication_phase(state(), String.t()) :: :final | :provisional | nil
  def latest_publication_phase(state, causal_unit_id) do
    state
    |> all(:reply_publications)
    |> Enum.filter(&(&1.causal_unit_id == causal_unit_id))
    |> Enum.map(& &1.phase)
    |> Enum.sort_by(&phase_rank/1, :desc)
    |> List.first()
  end

  @spec pending_recovery_tasks(state(), String.t()) :: [struct()]
  def pending_recovery_tasks(state, session_id) do
    state
    |> all(:recovery_tasks)
    |> Enum.filter(&(&1.session_id == session_id and &1.status == :pending))
  end

  defp apply_ops(state, ops) do
    Enum.reduce(ops, state, fn
      {:insert, table, id, row}, acc -> put_in(acc, [table, id], row)
    end)
  end

  defp phase_rank(:final), do: 2
  defp phase_rank(:provisional), do: 1

  defp record_id(:semantic_session_leases, %SemanticSessionLeaseRecord{row_id: id}), do: id
  defp record_id(:semantic_journal_entries, %SemanticJournalEntryRecord{entry_id: id}), do: id
  defp record_id(:semantic_frames, %SemanticFrameRecord{frame_id: id}), do: id
  defp record_id(:context_packs, %ContextPackRecord{context_pack_id: id}), do: id
  defp record_id(:strategy_profiles, %StrategyProfileRecord{strategy_profile_id: id}), do: id
  defp record_id(:tool_manifests, %ToolManifestRecord{manifest_id: id}), do: id
  defp record_id(:quality_checkpoints, %QualityCheckpointRecord{checkpoint_id: id}), do: id
  defp record_id(:reply_publications, %ReplyPublicationRecord{publication_id: id}), do: id
  defp record_id(:recovery_tasks, %RecoveryTaskRecord{task_id: id}), do: id
end
