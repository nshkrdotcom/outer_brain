defmodule OuterBrain.Contracts.ActionRequest do
  @moduledoc """
  Structured request compiled from semantic intent after manifest validation.
  """

  defstruct [:request_id, :session_id, :manifest_id, :route, args: %{}, provenance: %{}]

  @type t :: %__MODULE__{
          request_id: String.t(),
          session_id: String.t(),
          manifest_id: String.t(),
          route: String.t(),
          args: map(),
          provenance: map()
        }

  @spec new(map()) :: {:ok, t()} | {:error, term()}
  def new(%{
        request_id: request_id,
        session_id: session_id,
        manifest_id: manifest_id,
        route: route,
        args: args,
        provenance: provenance
      })
      when is_binary(request_id) and is_binary(session_id) and is_binary(manifest_id) and
             is_binary(route) and is_map(args) and is_map(provenance) do
    {:ok,
     %__MODULE__{
       request_id: request_id,
       session_id: session_id,
       manifest_id: manifest_id,
       route: route,
       args: args,
       provenance: provenance
     }}
  end

  def new(_attrs), do: {:error, :invalid_action_request}
end
