defmodule OuterBrain.Bridges.ReplyBuilder do
  @moduledoc """
  Builds provisional and final reply publication contracts and journal rows.
  """

  alias OuterBrain.Contracts.ReplyPublication
  alias OuterBrain.Journal.Tables.ReplyPublicationRecord

  @spec provisional(String.t(), String.t(), String.t()) ::
          {:ok, ReplyPublication.t(), struct()} | {:error, term()}
  def provisional(causal_unit_id, body, dedupe_key) do
    build(causal_unit_id, body, dedupe_key, :provisional)
  end

  @spec final(String.t(), String.t(), String.t()) ::
          {:ok, ReplyPublication.t(), struct()} | {:error, term()}
  def final(causal_unit_id, body, dedupe_key) do
    build(causal_unit_id, body, dedupe_key, :final)
  end

  defp build(causal_unit_id, body, dedupe_key, phase) do
    publication_id = "#{causal_unit_id}:#{phase}"

    with {:ok, publication} <-
           ReplyPublication.new(%{
             publication_id: publication_id,
             causal_unit_id: causal_unit_id,
             phase: phase,
             dedupe_key: dedupe_key,
             state: :published,
             body: body
           }),
         {:ok, row} <-
           ReplyPublicationRecord.new(%{
             publication_id: publication_id,
             causal_unit_id: causal_unit_id,
             phase: phase,
             state: :published,
             dedupe_key: dedupe_key,
             body: body
           }) do
      {:ok, publication, row}
    end
  end
end
