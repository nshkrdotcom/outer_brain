defmodule OuterBrain.Contracts.ReplyBodyBoundary do
  @moduledoc """
  Bounded preview and artifact-reference boundary for reply publication bodies.

  OuterBrain does not introduce a new artifact store here. Full semantic reply
  bodies are represented by fail-closed refs with integrity and schema evidence;
  inline `body` fields carry only a bounded redacted preview.
  """

  @phases [:provisional, :final]
  @preview_max_bytes 2_048
  @truncation_marker "\n[truncated]"
  @schema_name "outer_brain.reply_publication.body_ref.v1"
  @schema_hash "sha256:" <> Base.encode16(:crypto.hash(:sha256, @schema_name), case: :lower)
  @redaction_manifest_name "outer_brain.reply_publication.preview_redaction.v1"
  @redaction_manifest_hash "sha256:" <>
                             Base.encode16(
                               :crypto.hash(:sha256, @redaction_manifest_name),
                               case: :lower
                             )
  @redaction_manifest_ref @redaction_manifest_name <> ":" <> @redaction_manifest_hash
  @release_manifest_ref "phase5-v7-m4-artifact-boundary"
  @sha256_regex ~r/\Asha256:[0-9a-f]{64}\z/

  @required_ref_fields [
    "artifact_id",
    "content_hash",
    "content_hash_alg",
    "body_hash",
    "byte_size",
    "schema_name",
    "schema_hash",
    "schema_hash_alg",
    "media_type",
    "producer_repo",
    "tenant_scope",
    "sensitivity_class",
    "existing_store_ref",
    "store_security_posture_ref",
    "encryption_posture_ref",
    "retrieval_owner",
    "existing_fetch_or_restore_path",
    "safe_actions",
    "queue_key",
    "oversize_action",
    "release_manifest_ref",
    "redaction_manifest_ref",
    "causal_unit_id",
    "phase",
    "dedupe_key"
  ]

  @phase5_lifecycle_fields ["storage_tier", "retention_class", "fetch_policy"]
  @ref_field_atoms %{
    "artifact_id" => :artifact_id,
    "content_hash" => :content_hash,
    "content_hash_alg" => :content_hash_alg,
    "body_hash" => :body_hash,
    "byte_size" => :byte_size,
    "schema_name" => :schema_name,
    "schema_hash" => :schema_hash,
    "schema_hash_alg" => :schema_hash_alg,
    "media_type" => :media_type,
    "producer_repo" => :producer_repo,
    "tenant_scope" => :tenant_scope,
    "sensitivity_class" => :sensitivity_class,
    "existing_store_ref" => :existing_store_ref,
    "store_security_posture_ref" => :store_security_posture_ref,
    "encryption_posture_ref" => :encryption_posture_ref,
    "retrieval_owner" => :retrieval_owner,
    "existing_fetch_or_restore_path" => :existing_fetch_or_restore_path,
    "safe_actions" => :safe_actions,
    "queue_key" => :queue_key,
    "oversize_action" => :oversize_action,
    "release_manifest_ref" => :release_manifest_ref,
    "redaction_manifest_ref" => :redaction_manifest_ref,
    "causal_unit_id" => :causal_unit_id,
    "phase" => :phase,
    "dedupe_key" => :dedupe_key,
    "preview_hash" => :preview_hash,
    "storage_tier" => :storage_tier,
    "retention_class" => :retention_class,
    "fetch_policy" => :fetch_policy
  }

  @type body_ref :: %{String.t() => term()}
  @type built :: %{preview: String.t(), ref: body_ref()}

  @spec max_preview_bytes() :: pos_integer()
  def max_preview_bytes, do: @preview_max_bytes

  @spec schema_hash() :: String.t()
  def schema_hash, do: @schema_hash

  @spec redaction_manifest_ref() :: String.t()
  def redaction_manifest_ref, do: @redaction_manifest_ref

  @spec build(String.t(), atom(), String.t(), String.t(), keyword()) ::
          {:ok, built()} | {:error, term()}
  def build(causal_unit_id, phase, dedupe_key, body, opts \\ [])

  def build(causal_unit_id, phase, dedupe_key, body, opts)
      when is_binary(causal_unit_id) and phase in @phases and is_binary(dedupe_key) and
             is_binary(body) and is_list(opts) do
    preview = body |> redact() |> bounded_preview()
    content_hash = sha256_ref(body)

    ref = %{
      "artifact_id" => artifact_id(dedupe_key, phase, content_hash),
      "content_hash" => content_hash,
      "content_hash_alg" => "sha256",
      "body_hash" => content_hash,
      "byte_size" => byte_size(body),
      "schema_name" => @schema_name,
      "schema_hash" => @schema_hash,
      "schema_hash_alg" => "sha256",
      "media_type" => "text/plain; charset=utf-8",
      "producer_repo" => "outer_brain",
      "tenant_scope" => Keyword.get(opts, :tenant_scope, "unavailable_fail_closed"),
      "sensitivity_class" => "tenant_sensitive",
      "existing_store_ref" => Keyword.get(opts, :existing_store_ref, "unavailable_fail_closed"),
      "store_security_posture_ref" =>
        Keyword.get(opts, :store_security_posture_ref, "unavailable_fail_closed"),
      "encryption_posture_ref" =>
        Keyword.get(opts, :encryption_posture_ref, "unavailable_fail_closed"),
      "retrieval_owner" => "outer_brain.reply_publication",
      "existing_fetch_or_restore_path" => "unavailable_fail_closed",
      "safe_actions" => [
        "show_redacted_preview",
        "dedupe_by_body_hash",
        "quarantine_on_digest_mismatch"
      ],
      "queue_key" => dedupe_key,
      "oversize_action" => "reject_or_stream",
      "release_manifest_ref" => @release_manifest_ref,
      "redaction_manifest_ref" => @redaction_manifest_ref,
      "causal_unit_id" => causal_unit_id,
      "phase" => Atom.to_string(phase),
      "dedupe_key" => dedupe_key,
      "preview_hash" => sha256_ref(preview)
    }

    {:ok, %{preview: preview, ref: ref}}
  end

  def build(_causal_unit_id, _phase, _dedupe_key, _body, _opts),
    do: {:error, :invalid_reply_body_boundary_input}

  @spec valid_preview?(term()) :: boolean()
  def valid_preview?(body) when is_binary(body) do
    byte_size(body) <= @preview_max_bytes and redact(body) == body
  end

  def valid_preview?(_body), do: false

  @spec validate_ref(body_ref(), String.t(), atom(), String.t()) :: :ok | {:error, term()}
  def validate_ref(ref, causal_unit_id, phase, dedupe_key)
      when is_map(ref) and is_binary(causal_unit_id) and phase in @phases and
             is_binary(dedupe_key) do
    with :ok <- reject_phase5_lifecycle_fields(ref),
         :ok <- require_ref_fields(ref),
         :ok <- validate_primary_hash(ref, "content_hash", "content_hash_alg"),
         :ok <- validate_primary_hash(ref, "schema_hash", "schema_hash_alg"),
         :ok <- validate_expected(ref, "body_hash", field_value(ref, "content_hash")),
         :ok <- validate_expected(ref, "schema_name", @schema_name),
         :ok <- validate_expected(ref, "schema_hash", @schema_hash),
         :ok <- validate_expected(ref, "schema_hash_alg", "sha256"),
         :ok <- validate_expected(ref, "causal_unit_id", causal_unit_id),
         :ok <- validate_expected(ref, "phase", Atom.to_string(phase)),
         :ok <- validate_expected(ref, "dedupe_key", dedupe_key),
         :ok <- validate_expected(ref, "redaction_manifest_ref", @redaction_manifest_ref),
         :ok <- validate_byte_size(ref),
         :ok <- validate_safe_actions(ref) do
      validate_expected(ref, "existing_fetch_or_restore_path", "unavailable_fail_closed")
    end
  end

  def validate_ref(_ref, _causal_unit_id, _phase, _dedupe_key),
    do: {:error, :invalid_reply_body_ref}

  @spec equivalent_ref?(term(), term()) :: boolean()
  def equivalent_ref?(left, right) when is_map(left) and is_map(right) do
    body_hash(left) == body_hash(right) and
      field_value(left, "schema_hash") == field_value(right, "schema_hash") and
      field_value(left, "artifact_id") == field_value(right, "artifact_id")
  end

  def equivalent_ref?(_left, _right), do: false

  @spec ref_summary(term()) :: map() | nil
  def ref_summary(ref) when is_map(ref) do
    %{
      artifact_id: field_value(ref, "artifact_id"),
      body_hash: body_hash(ref),
      schema_hash: field_value(ref, "schema_hash"),
      redaction_manifest_ref: field_value(ref, "redaction_manifest_ref")
    }
  end

  def ref_summary(_ref), do: nil

  @spec body_hash(term()) :: String.t() | nil
  def body_hash(ref) when is_map(ref), do: field_value(ref, "body_hash")
  def body_hash(_ref), do: nil

  defp redact(body) do
    redacted_email =
      Regex.replace(
        ~r/\b[A-Z0-9._%+-]+@[A-Z0-9.-]+\.[A-Z]{2,}\b/i,
        body,
        "[REDACTED_EMAIL]"
      )

    Regex.replace(
      ~r/(?i)\b(api[_-]?key|token|password|secret)\s*[:=]\s*[^\s]+/,
      redacted_email,
      "\\1=[REDACTED]"
    )
  end

  defp bounded_preview(body) do
    if byte_size(body) <= @preview_max_bytes do
      body
    else
      body
      |> safe_prefix(@preview_max_bytes - byte_size(@truncation_marker))
      |> Kernel.<>(@truncation_marker)
    end
  end

  defp safe_prefix(_body, limit) when limit <= 0, do: ""

  defp safe_prefix(body, limit) do
    prefix = binary_part(body, 0, min(byte_size(body), limit))

    if String.valid?(prefix) do
      prefix
    else
      safe_prefix(body, limit - 1)
    end
  end

  defp sha256_ref(body), do: "sha256:" <> Base.encode16(:crypto.hash(:sha256, body), case: :lower)

  defp artifact_id(dedupe_key, phase, "sha256:" <> digest),
    do: "outer_brain.reply_publication:#{dedupe_key}:#{phase}:#{binary_part(digest, 0, 16)}"

  defp reject_phase5_lifecycle_fields(ref) do
    case Enum.find(@phase5_lifecycle_fields, &present?(ref, &1)) do
      nil -> :ok
      field -> {:error, {:phase5_lifecycle_field_forbidden, field}}
    end
  end

  defp require_ref_fields(ref) do
    missing = Enum.reject(@required_ref_fields, &present?(ref, &1))

    case missing do
      [] -> :ok
      fields -> {:error, {:missing_reply_body_ref_fields, fields}}
    end
  end

  defp validate_primary_hash(ref, hash_field, alg_field) do
    hash = field_value(ref, hash_field)
    alg = field_value(ref, alg_field)

    cond do
      alg != "sha256" ->
        {:error, {:invalid_primary_hash, alg_field}}

      not (is_binary(hash) and Regex.match?(@sha256_regex, hash)) ->
        {:error, {:invalid_primary_hash, hash_field}}

      true ->
        :ok
    end
  end

  defp validate_expected(ref, field, expected) do
    case field_value(ref, field) do
      ^expected -> :ok
      actual -> {:error, {:invalid_reply_body_ref_field, field, actual}}
    end
  end

  defp validate_byte_size(ref) do
    case field_value(ref, "byte_size") do
      value when is_integer(value) and value >= 0 -> :ok
      value -> {:error, {:invalid_reply_body_ref_byte_size, value}}
    end
  end

  defp validate_safe_actions(ref) do
    case field_value(ref, "safe_actions") do
      actions when is_list(actions) and actions != [] -> :ok
      actions -> {:error, {:invalid_reply_body_ref_safe_actions, actions}}
    end
  end

  defp present?(ref, field), do: not blank?(field_value(ref, field))

  defp blank?(value), do: is_nil(value) or value == "" or value == []

  defp field_value(ref, field) do
    case Map.fetch(ref, field) do
      {:ok, value} -> value
      :error -> Map.get(ref, Map.fetch!(@ref_field_atoms, field))
    end
  end
end
