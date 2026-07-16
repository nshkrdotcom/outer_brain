defmodule OuterBrain.Persistence.JournalPayloadPolicy do
  @moduledoc false

  @forbidden_keys MapSet.new(~w(
    access_token api_key authorization client_secret credential_material database_url
    password presigned_url private_key provider_native_body raw_artifact raw_context_pack
    raw_prompt raw_provider_body raw_provider_payload refresh_token secret signed_url
    tenant_secret token
  ))

  @spec validate(map()) :: :ok | {:error, term()}
  def validate(payload) when is_map(payload), do: validate_value(payload)

  defp validate_value(map) when is_map(map) do
    Enum.reduce_while(map, :ok, fn {key, value}, :ok ->
      case normalize_key(key) do
        {:ok, normalized_key} ->
          if MapSet.member?(@forbidden_keys, normalized_key) do
            {:halt, {:error, {:forbidden_journal_payload_key, normalized_key}}}
          else
            case validate_value(value) do
              :ok -> {:cont, :ok}
              {:error, _reason} = error -> {:halt, error}
            end
          end

        :error ->
          {:halt, {:error, :invalid_journal_payload_key}}
      end
    end)
  end

  defp validate_value(list) when is_list(list) do
    Enum.reduce_while(list, :ok, fn value, :ok ->
      case validate_value(value) do
        :ok -> {:cont, :ok}
        {:error, _reason} = error -> {:halt, error}
      end
    end)
  end

  defp validate_value(_value), do: :ok

  defp normalize_key(key) when is_binary(key), do: {:ok, String.downcase(key)}

  defp normalize_key(key) when is_atom(key),
    do: {:ok, key |> Atom.to_string() |> String.downcase()}

  defp normalize_key(_key), do: :error
end
