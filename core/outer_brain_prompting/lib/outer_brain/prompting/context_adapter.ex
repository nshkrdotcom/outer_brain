defmodule OuterBrain.Prompting.ContextAdapter do
  @moduledoc """
  Read-only adapter contract for external context contribution.
  """

  alias OuterBrain.Prompting.ContextFragment

  @callback fetch_fragments(request :: map(), runtime_binding :: map()) ::
              {:ok, [ContextFragment.t() | map()]} | {:error, term()}
end
