defmodule OuterBrain.Prompting.ImmutableArtifact do
  @moduledoc """
  Content-addressed OuterBrain artifact prepared for immutable owner storage.

  The payload is normalized before construction and deliberately redacted from
  inspection. Access fields are safe references; they are persisted separately
  from the descriptor so an opaque artifact reference is not bearer authority.
  """

  alias GroundPlane.Boundary.Codec
  alias GroundPlane.Contracts.ArtifactDescriptor

  @enforce_keys [
    :descriptor,
    :payload,
    :authority_packet_ref,
    :allowed_reader_refs,
    :allowed_operation_refs
  ]
  defstruct @enforce_keys

  @type t :: %__MODULE__{
          descriptor: ArtifactDescriptor.t(),
          payload: binary(),
          authority_packet_ref: String.t(),
          allowed_reader_refs: [String.t()],
          allowed_operation_refs: [String.t()]
        }

  @private_reasoning_keys MapSet.new(~w(
    chain_of_thought private_reasoning reasoning_trace scratchpad thinking
  ))
  @secret_text ~r/(?:api[_-]?key|access[_-]?token|authorization|bearer|client[_-]?secret|password|private[_-]?key|refresh[_-]?token)\s*[:=]\s*\S+/i

  @spec json(String.t(), map(), map() | keyword()) :: {:ok, t()} | {:error, term()}
  def json(role, payload, attrs) when is_binary(role) and is_map(payload) do
    with :ok <- validate_role(role),
         :ok <- reject_private_reasoning(payload),
         {:ok, normalized} <- Codec.normalize(payload) do
      build(role, Codec.encode!(normalized), attrs, "application/json")
    end
  end

  def json(_role, _payload, _attrs), do: {:error, :invalid_immutable_artifact}

  @spec text(String.t(), String.t(), map() | keyword()) :: {:ok, t()} | {:error, term()}
  def text(role, payload, attrs) when is_binary(role) and is_binary(payload) do
    with :ok <- validate_role(role),
         :ok <- validate_final_text(payload) do
      build(role, payload, attrs, "text/plain; charset=utf-8")
    end
  end

  def text(_role, _payload, _attrs), do: {:error, :invalid_immutable_artifact}

  @spec payload_digest(t()) :: String.t()
  def payload_digest(%__MODULE__{payload: payload}), do: sha256(payload)

  defp build(role, payload, attrs, default_media_type) do
    attrs = Map.new(attrs)

    with {:ok, tenant_ref} <- required_string(attrs, :tenant_ref),
         {:ok, authority_packet_ref} <- required_string(attrs, :authority_packet_ref),
         {:ok, producing_operation_ref} <- required_string(attrs, :producing_operation_ref),
         {:ok, allowed_reader_refs} <- required_refs(attrs, :allowed_reader_refs),
         {:ok, allowed_operation_refs} <- required_refs(attrs, :allowed_operation_refs),
         {:ok, causal_parent_refs} <- optional_refs(attrs, :causal_parent_refs),
         {:ok, provenance} <- required_map(attrs, :provenance),
         :ok <- reject_private_reasoning(provenance),
         {:ok, retention} <- required_map(attrs, :retention) do
      content_digest = sha256(payload)
      suffix = artifact_suffix(tenant_ref, role, content_digest)

      descriptor =
        ArtifactDescriptor.new!(%{
          artifact_ref: "artifact://outer-brain/#{role}/#{suffix}",
          tenant_ref: tenant_ref,
          owner_ref: "owner://outer-brain",
          content_digest: content_digest,
          size_bytes: byte_size(payload),
          media_type: value(attrs, :media_type, default_media_type),
          schema_ref: value(attrs, :schema_ref, "schema://outer-brain/#{role}/v1"),
          schema_version: value(attrs, :schema_version, 1),
          classification: value(attrs, :classification, "confidential"),
          provenance: provenance,
          causal_parent_refs: causal_parent_refs,
          producing_operation_ref: producing_operation_ref,
          retention: retention,
          deletion_state: "active",
          location_ref: "artifact-location://outer-brain/postgres/#{suffix}"
        })

      {:ok,
       %__MODULE__{
         descriptor: descriptor,
         payload: payload,
         authority_packet_ref: authority_packet_ref,
         allowed_reader_refs: allowed_reader_refs,
         allowed_operation_refs: allowed_operation_refs
       }}
    end
  rescue
    ArgumentError -> {:error, :invalid_immutable_artifact}
  end

  defp validate_role(role) do
    if String.match?(role, ~r/\A[a-z][a-z0-9-]*\z/),
      do: :ok,
      else: {:error, :invalid_artifact_role}
  end

  defp validate_final_text(payload) do
    cond do
      String.trim(payload) == "" ->
        {:error, :empty_artifact_payload}

      not String.valid?(payload) ->
        {:error, :invalid_artifact_encoding}

      Regex.match?(@secret_text, payload) ->
        {:error, :secret_bearing_artifact_payload}

      String.contains?(payload, "-----BEGIN PRIVATE KEY-----") ->
        {:error, :secret_bearing_artifact_payload}

      true ->
        :ok
    end
  end

  defp reject_private_reasoning(map) when is_map(map) do
    Enum.reduce_while(map, :ok, fn {key, nested}, :ok ->
      normalized_key = key |> to_string() |> String.downcase()

      if MapSet.member?(@private_reasoning_keys, normalized_key) do
        {:halt, {:error, {:private_reasoning_artifact_key, normalized_key}}}
      else
        case reject_private_reasoning(nested) do
          :ok -> {:cont, :ok}
          {:error, _reason} = error -> {:halt, error}
        end
      end
    end)
  end

  defp reject_private_reasoning(list) when is_list(list) do
    Enum.reduce_while(list, :ok, fn nested, :ok ->
      case reject_private_reasoning(nested) do
        :ok -> {:cont, :ok}
        {:error, _reason} = error -> {:halt, error}
      end
    end)
  end

  defp reject_private_reasoning(_value), do: :ok

  defp required_string(attrs, field) do
    case value(attrs, field) do
      value when is_binary(value) and value != "" -> {:ok, value}
      _other -> {:error, {:missing_artifact_field, field}}
    end
  end

  defp required_refs(attrs, field) do
    case value(attrs, field) do
      refs when is_list(refs) and refs != [] -> validate_refs(refs, field)
      _other -> {:error, {:missing_artifact_field, field}}
    end
  end

  defp optional_refs(attrs, field) do
    attrs |> value(field, []) |> validate_refs(field)
  end

  defp validate_refs(refs, field) when is_list(refs) do
    refs = Enum.uniq(refs)

    if Enum.all?(refs, &(is_binary(&1) and &1 != "")),
      do: {:ok, refs},
      else: {:error, {:invalid_artifact_field, field}}
  end

  defp validate_refs(_refs, field), do: {:error, {:invalid_artifact_field, field}}

  defp required_map(attrs, field) do
    case value(attrs, field) do
      map when is_map(map) -> {:ok, map}
      _other -> {:error, {:missing_artifact_field, field}}
    end
  end

  defp artifact_suffix(tenant_ref, role, content_digest) do
    [tenant_ref, role, content_digest]
    |> Enum.join("\0")
    |> then(&:crypto.hash(:sha256, &1))
    |> Base.encode16(case: :lower)
  end

  defp sha256(payload),
    do: "sha256:" <> Base.encode16(:crypto.hash(:sha256, payload), case: :lower)

  defp value(attrs, key, default \\ nil),
    do: Map.get(attrs, key, Map.get(attrs, Atom.to_string(key), default))
end

defimpl Inspect, for: OuterBrain.Prompting.ImmutableArtifact do
  import Inspect.Algebra

  def inspect(artifact, opts) do
    safe = %{
      descriptor: artifact.descriptor,
      payload: "[REDACTED ARTIFACT PAYLOAD]",
      authority_packet_ref: artifact.authority_packet_ref,
      allowed_reader_refs: artifact.allowed_reader_refs,
      allowed_operation_refs: artifact.allowed_operation_refs
    }

    concat(["#OuterBrain.Prompting.ImmutableArtifact<", to_doc(safe, opts), ">"])
  end
end
