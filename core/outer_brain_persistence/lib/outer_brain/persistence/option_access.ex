defmodule OuterBrain.Persistence.OptionAccess do
  @moduledoc false

  @missing :__outer_brain_persistence_option_missing__

  @spec to_map(keyword() | map()) :: map()
  def to_map(opts) when is_list(opts), do: Map.new(opts)
  def to_map(opts) when is_map(opts), do: opts

  @spec value(map(), atom(), term()) :: term()
  def value(attrs, field, default \\ nil) when is_map(attrs) and is_atom(field) do
    string_field = Atom.to_string(field)

    cond do
      Map.has_key?(attrs, field) -> Map.fetch!(attrs, field)
      Map.has_key?(attrs, string_field) -> Map.fetch!(attrs, string_field)
      true -> default
    end
  end

  @spec missing() :: atom()
  def missing, do: @missing
end
