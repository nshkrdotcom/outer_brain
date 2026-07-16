defmodule OuterBrain.Persistence.ArtifactMetadataPolicy do
  @moduledoc false

  alias GroundPlane.Contracts.ArtifactDescriptor

  @forbidden_keys MapSet.new(~w(database_url presigned_url signed_url))
  @signed_location_markers ~w(x-amz-signature x-goog-signature signature= access_token= token=)

  @spec validate(ArtifactDescriptor.t()) :: :ok | {:error, term()}
  def validate(%ArtifactDescriptor{} = descriptor) do
    with :ok <- reject_forbidden_key(descriptor.provenance),
         :ok <- reject_forbidden_key(descriptor.retention),
         :ok <- validate_location_ref(descriptor.location_ref) do
      :ok
    end
  end

  defp reject_forbidden_key(map) when is_map(map) do
    Enum.reduce_while(map, :ok, fn {key, value}, :ok ->
      normalized_key = key |> to_string() |> String.downcase()

      cond do
        MapSet.member?(@forbidden_keys, normalized_key) ->
          {:halt, {:error, {:secret_artifact_metadata_key, normalized_key}}}

        true ->
          case reject_forbidden_key(value) do
            :ok -> {:cont, :ok}
            {:error, _reason} = error -> {:halt, error}
          end
      end
    end)
  end

  defp reject_forbidden_key(list) when is_list(list) do
    Enum.reduce_while(list, :ok, fn value, :ok ->
      case reject_forbidden_key(value) do
        :ok -> {:cont, :ok}
        {:error, _reason} = error -> {:halt, error}
      end
    end)
  end

  defp reject_forbidden_key(_value), do: :ok

  defp validate_location_ref(nil), do: :ok

  defp validate_location_ref(location_ref) do
    normalized = String.downcase(location_ref)

    if String.starts_with?(normalized, ["http://", "https://"]) or
         Enum.any?(@signed_location_markers, &String.contains?(normalized, &1)) do
      {:error, :non_opaque_artifact_location_ref}
    else
      :ok
    end
  end
end
