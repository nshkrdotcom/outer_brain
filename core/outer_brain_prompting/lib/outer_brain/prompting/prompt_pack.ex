defmodule OuterBrain.Prompting.PromptPack do
  @moduledoc """
  Stable prompt-pack shape used for replay and quality checkpoints.
  """

  alias OuterBrain.Contracts.ToolManifestSnapshot
  alias OuterBrain.Prompting.{ContextPack, StrategyProfile}

  @spec build(map(), ToolManifestSnapshot.t(), atom()) :: {:ok, map()} | {:error, term()}
  def build(context_pack, %ToolManifestSnapshot{} = snapshot, strategy_name)
      when is_map(context_pack) do
    with {:ok, strategy} <- StrategyProfile.fetch(strategy_name) do
      {:ok,
       %{
         strategy: strategy,
         context: context_pack,
         tools: ToolManifestSnapshot.route_names(snapshot),
         manifest_id: snapshot.manifest_id,
         schema_hash: snapshot.schema_hash
       }}
    end
  end

  @spec build_from_frame(struct(), ToolManifestSnapshot.t(), atom(), [String.t()]) ::
          {:ok, map()} | {:error, term()}
  def build_from_frame(frame, %ToolManifestSnapshot{} = snapshot, strategy_name, refs) do
    build_from_frame(frame, snapshot, strategy_name, refs, [])
  end

  @spec build_from_frame(struct(), ToolManifestSnapshot.t(), atom(), [String.t()], keyword()) ::
          {:ok, map()} | {:error, term()}
  def build_from_frame(frame, %ToolManifestSnapshot{} = snapshot, strategy_name, refs, opts) do
    frame
    |> ContextPack.build(refs, opts)
    |> build(snapshot, strategy_name)
  end
end
