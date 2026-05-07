defmodule OuterBrain.Prompting.ContextFragment do
  @moduledoc """
  Structured fragment contributed by a read-only context adapter.
  """

  alias OuterBrain.Contracts.PersistencePosture

  @enforce_keys [:fragment_id, :content, :provenance, :staleness]
  defstruct [
    :fragment_id,
    :schema_ref,
    :schema_version,
    :content,
    :provenance,
    :staleness,
    persistence_posture: PersistencePosture.memory(:context_fragment),
    metadata: %{}
  ]

  @type t :: %__MODULE__{
          fragment_id: String.t(),
          schema_ref: String.t() | nil,
          schema_version: String.t() | pos_integer() | nil,
          content: map() | String.t() | [term()],
          provenance: map(),
          staleness: map(),
          persistence_posture: PersistencePosture.t(),
          metadata: map()
        }

  @raw_keys [
    :authorization,
    :provider_account_id,
    :provider_payload,
    :raw_prompt,
    :raw_provider_payload,
    :secret,
    :token,
    "authorization",
    "provider_account_id",
    "provider_payload",
    "raw_prompt",
    "raw_provider_payload",
    "secret",
    "token"
  ]

  @spec new(map() | keyword() | t()) :: {:ok, t()} | {:error, :invalid_context_fragment}
  def new(%__MODULE__{} = fragment), do: {:ok, fragment}
  def new(attrs) when is_list(attrs), do: attrs |> Enum.into(%{}) |> new()

  def new(attrs) when is_map(attrs) do
    with fragment_id when is_binary(fragment_id) and byte_size(fragment_id) > 0 <-
           fetch_value(attrs, :fragment_id),
         content <- fetch_value(attrs, :content),
         true <- not is_nil(content),
         :ok <- reject_raw_payload(content),
         provenance when is_map(provenance) <- fetch_value(attrs, :provenance),
         staleness when is_map(staleness) <- fetch_value(attrs, :staleness),
         persistence_posture <- PersistencePosture.resolve(:context_fragment, attrs),
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
         persistence_posture: persistence_posture,
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

  defp reject_raw_payload(%{} = map) do
    case Enum.find(map, fn {key, value} ->
           key in @raw_keys or raw_payload?(value)
         end) do
      nil -> :ok
      {key, _value} -> {:error, {:raw_context_fragment_payload_forbidden, key}}
    end
  end

  defp reject_raw_payload(values) when is_list(values) do
    if Enum.any?(values, &raw_payload?/1) do
      {:error, :raw_context_fragment_payload_forbidden}
    else
      :ok
    end
  end

  defp reject_raw_payload(_value), do: :ok

  defp raw_payload?(%{} = map) do
    Enum.any?(map, fn {key, value} ->
      key in @raw_keys or raw_payload?(value)
    end)
  end

  defp raw_payload?(values) when is_list(values), do: Enum.any?(values, &raw_payload?/1)
  defp raw_payload?(_value), do: false
end
