defmodule OuterBrain.Persistence.SemanticFailureMapper do
  @moduledoc false

  alias OuterBrain.Contracts.SemanticFailure

  @spec from_schema!(struct()) :: SemanticFailure.t()
  def from_schema!(schema) do
    case SemanticFailure.from_payload(schema.payload) do
      {:ok, failure} ->
        failure

      {:error, reason} ->
        raise ArgumentError, "invalid semantic failure payload: #{inspect(reason)}"
    end
  end
end
