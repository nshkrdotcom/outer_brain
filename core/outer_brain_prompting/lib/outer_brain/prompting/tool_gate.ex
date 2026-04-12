defmodule OuterBrain.Prompting.ToolGate do
  @moduledoc """
  Gate that ensures model-selected work still matches the stored manifest.
  """

  alias OuterBrain.Contracts.ToolManifestSnapshot

  @spec validate(ToolManifestSnapshot.t(), map()) :: :ok | {:error, term()}
  def validate(%ToolManifestSnapshot{} = snapshot, selection) do
    ToolManifestSnapshot.selection_valid?(snapshot, selection)
  end
end
