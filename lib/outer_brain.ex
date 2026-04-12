defmodule OuterBrain do
  @moduledoc """
  Starter library shell for OuterBrain.

  The repository currently exists to anchor the semantic-runtime layer that sits
  above Citadel and below host-facing conversational surfaces.
  """

  @doc """
  Returns the default starter marker.
  """
  @spec hello() :: :world
  def hello, do: :world
end
