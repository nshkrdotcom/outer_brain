defmodule OuterBrain.Persistence.RecoveryTaskMapper do
  @moduledoc false

  alias OuterBrain.Journal.Tables.RecoveryTaskRecord

  @recovery_reasons [:ambiguous_submission]
  @recovery_reasons_by_schema Map.new(@recovery_reasons, &{Atom.to_string(&1), &1})

  @spec allowed_reason?(atom()) :: boolean()
  def allowed_reason?(reason), do: reason in @recovery_reasons

  @spec reason_to_schema(atom()) :: String.t()
  def reason_to_schema(reason), do: Atom.to_string(reason)

  @spec from_schema(struct()) :: RecoveryTaskRecord.t()
  def from_schema(schema) do
    %RecoveryTaskRecord{
      task_id: schema.task_id,
      session_id: schema.session_id,
      reason: recovery_reason!(schema.reason),
      status: schema.status
    }
  end

  defp recovery_reason!(reason) when is_binary(reason) do
    case Map.fetch(@recovery_reasons_by_schema, reason) do
      {:ok, reason_atom} ->
        reason_atom

      :error ->
        raise ArgumentError, "unknown recovery task reason: #{inspect(reason)}"
    end
  end
end
