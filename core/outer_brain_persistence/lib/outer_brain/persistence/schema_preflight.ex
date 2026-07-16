defmodule OuterBrain.Persistence.SchemaPreflight do
  @moduledoc false

  @required_tables ~w(
    schema_migrations
    semantic_session_leases
    semantic_journal_entries
    recovery_tasks
    reply_publications
    outer_brain_artifact_descriptors
    outer_brain_semantic_contexts
  )
  @required_indexes ~w(
    outer_brain_semantic_contexts_reference_search_idx
  )
  @required_triggers ~w(
    outer_brain_artifact_descriptors_immutable
    outer_brain_semantic_contexts_immutable
  )

  @spec check(module()) :: :ok | {:error, term()}
  def check(repo) when is_atom(repo) do
    with :ok <- require_running(repo),
         :ok <- require_tables(repo),
         :ok <- require_indexes(repo),
         :ok <- require_triggers(repo),
         :ok <- require_migrations(repo) do
      :ok
    end
  rescue
    exception -> {:error, {:repository_preflight_failed, exception.__struct__}}
  catch
    :exit, _reason -> {:error, :repository_unavailable}
  end

  defp require_indexes(repo) do
    {:ok, %{rows: rows}} =
      repo.query(
        "SELECT indexname FROM pg_indexes WHERE schemaname = 'public' AND indexname = ANY($1::text[])",
        [@required_indexes]
      )

    require_names(rows, @required_indexes, :missing_durable_indexes)
  end

  defp require_triggers(repo) do
    {:ok, %{rows: rows}} =
      repo.query(
        "SELECT tgname FROM pg_trigger WHERE NOT tgisinternal AND tgname = ANY($1::text[])",
        [@required_triggers]
      )

    require_names(rows, @required_triggers, :missing_immutability_triggers)
  end

  defp require_names(rows, required, error_tag) do
    present = MapSet.new(List.flatten(rows))

    case Enum.reject(required, &MapSet.member?(present, &1)) do
      [] -> :ok
      missing -> {:error, {error_tag, missing}}
    end
  end

  defp require_running(repo) do
    case Process.whereis(repo) do
      pid when is_pid(pid) -> :ok
      nil -> {:error, {:repository_not_running, repo}}
    end
  end

  defp require_tables(repo) do
    {:ok, %{rows: rows}} =
      repo.query(
        "SELECT name FROM unnest($1::text[]) AS name WHERE to_regclass('public.' || name) IS NOT NULL",
        [@required_tables]
      )

    present = MapSet.new(List.flatten(rows))

    case Enum.reject(@required_tables, &MapSet.member?(present, &1)) do
      [] -> :ok
      missing -> {:error, {:missing_durable_tables, missing}}
    end
  end

  defp require_migrations(repo) do
    pending =
      repo
      |> Ecto.Migrator.migrations(migrations_path())
      |> Enum.filter(&match?({:down, _version, _name}, &1))

    if pending == [], do: :ok, else: {:error, {:pending_migrations, pending}}
  end

  defp migrations_path do
    :outer_brain_persistence
    |> :code.priv_dir()
    |> to_string()
    |> Path.join("repo/migrations")
  end
end
