defmodule OuterBrain.ContextABI.RuntimeDeps do
  @moduledoc """
  Explicit runtime dependencies for Context ABI callers.
  """

  defstruct compiler: OuterBrain.ContextABI.Compiler,
            renderer: nil,
            token_meter: nil,
            clock: nil

  @type t :: %__MODULE__{
          compiler: module() | nil,
          renderer: module() | nil,
          token_meter: module() | nil,
          clock: module() | nil
        }
end
