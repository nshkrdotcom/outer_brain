defmodule OuterBrain.ContextABI.Canonical do
  @moduledoc """
  Canonical encoding and digest helpers for Context ABI facts.
  """

  alias GroundPlane.Boundary.Codec
  alias OuterBrain.ContextABI.ContextPacket

  @spec digest(term()) :: String.t()
  def digest(term), do: term |> normalize_for_boundary() |> Codec.digest()

  @spec packet_hash(ContextPacket.t()) :: String.t()
  def packet_hash(%ContextPacket{} = packet) do
    packet
    |> ContextPacket.hash_input()
    |> digest()
  end

  @spec normalize_for_boundary(term()) :: term()
  def normalize_for_boundary(%{__struct__: _} = value),
    do: value |> Map.from_struct() |> normalize_for_boundary()

  def normalize_for_boundary(%{} = map) do
    map
    |> Enum.map(fn {key, value} -> {to_string(key), normalize_for_boundary(value)} end)
    |> Map.new()
  end

  def normalize_for_boundary(values) when is_list(values),
    do: Enum.map(values, &normalize_for_boundary/1)

  def normalize_for_boundary(value) when is_atom(value), do: Atom.to_string(value)
  def normalize_for_boundary(value), do: value
end
