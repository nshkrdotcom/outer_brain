defmodule OuterBrain.Persistence.RecoveryTaskRepository do
  @moduledoc false

  import Ecto.Query

  alias OuterBrain.Journal.Tables.RecoveryTaskRecord
  alias OuterBrain.Persistence.RecoveryTaskMapper
  alias OuterBrain.Persistence.Schemas.RecoveryTask

  @spec record(module(), String.t(), RecoveryTaskRecord.t()) ::
          {:ok, RecoveryTaskRecord.t()} | {:error, Ecto.Changeset.t() | term()}
  def record(repo, tenant_id, %RecoveryTaskRecord{reason: reason} = task) do
    if RecoveryTaskMapper.allowed_reason?(reason) do
      do_record(repo, tenant_id, task)
    else
      {:error, {:invalid_recovery_task_reason, task.reason}}
    end
  end

  @spec pending(module(), String.t(), String.t()) :: [RecoveryTaskRecord.t()]
  def pending(repo, tenant_id, session_id)
      when is_binary(tenant_id) and is_binary(session_id) do
    RecoveryTask
    |> where(
      [task],
      task.tenant_id == ^tenant_id and task.session_id == ^session_id and task.status == :pending
    )
    |> order_by([task], asc: task.inserted_at)
    |> repo.all()
    |> Enum.map(&RecoveryTaskMapper.from_schema/1)
  end

  defp do_record(repo, tenant_id, task) do
    reason = RecoveryTaskMapper.reason_to_schema(task.reason)

    changeset =
      RecoveryTask.changeset(%RecoveryTask{}, %{
        task_id: task.task_id,
        tenant_id: tenant_id,
        session_id: task.session_id,
        reason: reason,
        status: task.status
      })

    case repo.insert(changeset,
           on_conflict: [set: [reason: reason, status: task.status]],
           conflict_target: :task_id
         ) do
      {:ok, _schema} -> {:ok, task}
      {:error, changeset} -> {:error, changeset}
    end
  end
end
