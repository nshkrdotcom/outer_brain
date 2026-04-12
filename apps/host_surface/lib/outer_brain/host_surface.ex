defmodule OuterBrain.HostSurface do
  @moduledoc """
  Minimal host-facing entrypoint for starting semantic sessions and publishing
  provisional replies.
  """

  alias OuterBrain.Bridges.ReplyBuilder
  alias OuterBrain.Runtime.SessionOwner

  @spec open_session(String.t(), String.t(), keyword()) ::
          {:ok, atom(), struct()} | {:error, term()}
  def open_session(session_id, holder, opts \\ []) do
    now = Keyword.get(opts, :now, DateTime.utc_now())
    epoch = Keyword.get(opts, :epoch, 1)
    SessionOwner.acquire(OuterBrain.Runtime.LeaseRegistry, session_id, holder, epoch, now, opts)
  end

  @spec provisional_reply(String.t(), String.t()) :: {:ok, struct(), struct()} | {:error, term()}
  def provisional_reply(causal_unit_id, body) do
    ReplyBuilder.provisional(causal_unit_id, body, "#{causal_unit_id}:provisional")
  end
end
