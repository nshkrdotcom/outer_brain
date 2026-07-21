defmodule OuterBrain.Persistence.ArtifactAccess do
  @moduledoc """
  Safe, exact authorization evidence required to resolve an OuterBrain artifact.

  An artifact ref is never bearer authority. The tenant, reader, operation, and
  authority packet must all agree with the immutable payload row.
  """

  @enforce_keys [:tenant_ref, :reader_ref, :operation_ref, :authority_packet_ref]
  defstruct @enforce_keys

  @type t :: %__MODULE__{
          tenant_ref: String.t(),
          reader_ref: String.t(),
          operation_ref: String.t(),
          authority_packet_ref: String.t()
        }

  @spec new(map() | keyword() | t()) :: {:ok, t()} | {:error, :invalid_artifact_access}
  def new(%__MODULE__{} = access), do: access |> Map.from_struct() |> new()

  def new(attrs) when is_map(attrs) or is_list(attrs) do
    attrs = Map.new(attrs)

    with {:ok, tenant_ref} <- required(attrs, :tenant_ref),
         {:ok, reader_ref} <- required(attrs, :reader_ref),
         {:ok, operation_ref} <- required(attrs, :operation_ref),
         {:ok, authority_packet_ref} <- required(attrs, :authority_packet_ref) do
      {:ok,
       %__MODULE__{
         tenant_ref: tenant_ref,
         reader_ref: reader_ref,
         operation_ref: operation_ref,
         authority_packet_ref: authority_packet_ref
       }}
    else
      _other -> {:error, :invalid_artifact_access}
    end
  end

  def new(_attrs), do: {:error, :invalid_artifact_access}

  @spec new!(map() | keyword() | t()) :: t()
  def new!(attrs) do
    case new(attrs) do
      {:ok, access} -> access
      {:error, reason} -> raise ArgumentError, "invalid artifact access: #{inspect(reason)}"
    end
  end

  defp required(attrs, key) do
    case Map.get(attrs, key, Map.get(attrs, Atom.to_string(key))) do
      value when is_binary(value) and value != "" -> {:ok, value}
      _other -> :error
    end
  end
end
