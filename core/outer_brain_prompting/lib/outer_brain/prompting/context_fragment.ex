defmodule OuterBrain.Prompting.ContextFragment do
  @moduledoc """
  Structured fragment contributed by a read-only context adapter.
  """

  @enforce_keys [:fragment_id, :content, :provenance, :staleness]
  defstruct [
    :fragment_id,
    :schema_ref,
    :schema_version,
    :content,
    :provenance,
    :staleness,
    metadata: %{}
  ]

  @type t :: %__MODULE__{
          fragment_id: String.t(),
          schema_ref: String.t() | nil,
          schema_version: String.t() | pos_integer() | nil,
          content: map() | String.t() | [term()],
          provenance: map(),
          staleness: map(),
          metadata: map()
        }

  @spec new(map() | keyword() | t()) :: {:ok, t()} | {:error, :invalid_context_fragment}
  def new(%__MODULE__{} = fragment), do: {:ok, fragment}
  def new(attrs) when is_list(attrs), do: attrs |> Enum.into(%{}) |> new()

  def new(attrs) when is_map(attrs) do
    with fragment_id when is_binary(fragment_id) and byte_size(fragment_id) > 0 <-
           fetch_value(attrs, :fragment_id),
         content <- fetch_value(attrs, :content),
         true <- not is_nil(content),
         provenance when is_map(provenance) <- fetch_value(attrs, :provenance),
         staleness when is_map(staleness) <- fetch_value(attrs, :staleness),
         metadata <- fetch_value(attrs, :metadata) || %{},
         true <- is_map(metadata) do
      {:ok,
       %__MODULE__{
         fragment_id: fragment_id,
         schema_ref: fetch_value(attrs, :schema_ref),
         schema_version: fetch_value(attrs, :schema_version),
         content: content,
         provenance: provenance,
         staleness: staleness,
         metadata: metadata
       }}
    else
      _ -> {:error, :invalid_context_fragment}
    end
  end

  def new(_attrs), do: {:error, :invalid_context_fragment}

  defp fetch_value(%{__struct__: _} = attrs, key),
    do: attrs |> Map.from_struct() |> fetch_value(key)

  defp fetch_value(attrs, key) do
    Map.get(attrs, key) || Map.get(attrs, Atom.to_string(key))
  end
end
