defmodule OuterBrain.Core.ActionRequestCompiler do
  @moduledoc """
  Compiles a manifest-validated selection into a structured action request.
  """

  alias OuterBrain.Contracts.{ActionRequest, ToolManifestSnapshot}
  alias OuterBrain.Core.Clarification
  alias OuterBrain.Core.SemanticFrame

  @spec compile(SemanticFrame.t(), ToolManifestSnapshot.t(), map(), number()) ::
          {:ok, ActionRequest.t()} | {:error, term()}
  def compile(
        %SemanticFrame{session_id: session_id} = frame,
        %ToolManifestSnapshot{} = snapshot,
        selection,
        confidence
      ) do
    with false <- Clarification.required?(confidence),
         :ok <- ToolManifestSnapshot.selection_valid?(snapshot, selection),
         {:ok, request} <-
           ActionRequest.new(%{
             request_id: Map.get(selection, :request_id, "request_#{session_id}"),
             session_id: session_id,
             manifest_id: snapshot.manifest_id,
             route: Map.fetch!(selection, :route),
             args: Map.put(Map.get(selection, :args, %{}), "objective", frame.objective),
             provenance: Map.get(selection, :provenance, %{})
           }) do
      {:ok, request}
    else
      true -> {:error, :clarification_required}
      error -> error
    end
  end
end
