defmodule OuterBrain.AuthorityEvidence do
  @moduledoc """
  Tenant-scoped, ref-only OuterBrain authority evidence.
  """

  alias OuterBrain.Contracts.PersistencePosture

  defmodule Evidence do
    @moduledoc """
    Tenant-scoped, ref-only authority evidence record.
    """

    @type t :: %__MODULE__{
            tenant_ref: String.t(),
            authority_packet_ref: String.t(),
            prompt_provenance_ref: String.t(),
            semantic_evidence_ref: String.t(),
            memory_fact_refs: [String.t()],
            redaction_ref: String.t(),
            trace_ref: String.t() | nil,
            privacy_class: :tenant_private | :redacted_summary | :operator_visible | :suppressed,
            suppression_state: :visible | :suppressed | :redacted,
            persistence_posture: PersistencePosture.t(),
            raw_material_present?: false
          }

    defstruct [
      :tenant_ref,
      :authority_packet_ref,
      :prompt_provenance_ref,
      :semantic_evidence_ref,
      :memory_fact_refs,
      :redaction_ref,
      :trace_ref,
      :privacy_class,
      :suppression_state,
      :persistence_posture,
      raw_material_present?: false
    ]
  end

  @required_refs [
    :tenant_ref,
    :authority_packet_ref,
    :prompt_provenance_ref,
    :semantic_evidence_ref,
    :memory_fact_refs,
    :redaction_ref
  ]

  @forbidden_material [
    :api_key,
    :auth_json,
    :provider_payload,
    :raw_prompt,
    :raw_secret,
    :raw_token,
    :target_credentials
  ]

  @privacy_classes [:tenant_private, :redacted_summary, :operator_visible, :suppressed]
  @privacy_lookup Map.new(@privacy_classes, &{Atom.to_string(&1), &1})
  @suppression_states [:visible, :suppressed, :redacted]
  @suppression_lookup Map.new(@suppression_states, &{Atom.to_string(&1), &1})
  @known_fields @required_refs ++
                  @forbidden_material ++
                  [
                    :trace_ref,
                    :privacy_class,
                    :suppression_state,
                    :persistence_posture,
                    :persistence_profile,
                    :persistence_profile_ref
                  ]

  @spec record(map() | keyword()) ::
          {:ok, Evidence.t()}
          | {:error, {:missing_authority_evidence_refs, [atom()]}}
          | {:error, {:forbidden_authority_evidence_material, [atom()]}}
          | {:error, {:cross_tenant_evidence_refs, [String.t()]}}
          | {:error, {:invalid_authority_evidence_enum, atom(), term()}}
  def record(attrs) when is_map(attrs) or is_list(attrs) do
    attrs = normalize(attrs)

    with [] <- forbidden_material(attrs),
         [] <- missing_refs(attrs),
         {:ok, privacy_class} <- enum(attrs, :privacy_class, @privacy_lookup, :tenant_private),
         {:ok, suppression_state} <-
           enum(attrs, :suppression_state, @suppression_lookup, :visible),
         [] <- cross_tenant_refs(attrs) do
      {:ok, evidence(attrs, privacy_class, suppression_state)}
    else
      [_ | _] = values ->
        classify_list_error(values)

      {:error, reason} ->
        {:error, reason}
    end
  end

  defp classify_list_error(values) do
    cond do
      Enum.any?(values, &(&1 in @forbidden_material)) ->
        {:error, {:forbidden_authority_evidence_material, values}}

      Enum.any?(values, &(&1 in @required_refs)) ->
        {:error, {:missing_authority_evidence_refs, values}}

      true ->
        {:error, {:cross_tenant_evidence_refs, values}}
    end
  end

  defp evidence(attrs, privacy_class, suppression_state) do
    %Evidence{
      tenant_ref: Map.fetch!(attrs, :tenant_ref),
      authority_packet_ref: Map.fetch!(attrs, :authority_packet_ref),
      prompt_provenance_ref: Map.fetch!(attrs, :prompt_provenance_ref),
      semantic_evidence_ref: Map.fetch!(attrs, :semantic_evidence_ref),
      memory_fact_refs: List.wrap(Map.fetch!(attrs, :memory_fact_refs)),
      redaction_ref: Map.fetch!(attrs, :redaction_ref),
      trace_ref: Map.get(attrs, :trace_ref),
      privacy_class: privacy_class,
      suppression_state: suppression_state,
      persistence_posture: PersistencePosture.resolve(:authority_evidence, attrs)
    }
  end

  defp forbidden_material(attrs), do: Enum.filter(@forbidden_material, &Map.has_key?(attrs, &1))
  defp missing_refs(attrs), do: Enum.reject(@required_refs, &present?(Map.get(attrs, &1)))

  defp enum(attrs, field, lookup, default) do
    case Map.get(attrs, field, default) do
      value when is_atom(value) ->
        if value in Map.values(lookup) do
          {:ok, value}
        else
          {:error, {:invalid_authority_evidence_enum, field, value}}
        end

      value when is_binary(value) ->
        case Map.fetch(lookup, value) do
          {:ok, atom} -> {:ok, atom}
          :error -> {:error, {:invalid_authority_evidence_enum, field, value}}
        end

      value ->
        {:error, {:invalid_authority_evidence_enum, field, value}}
    end
  end

  defp cross_tenant_refs(attrs) do
    tenant_id = attrs |> Map.get(:tenant_ref, "") |> String.replace_prefix("tenant://", "")

    attrs
    |> Map.get(:memory_fact_refs, [])
    |> List.wrap()
    |> Enum.reject(&String.contains?(&1, tenant_id))
  end

  defp normalize(attrs) when is_list(attrs), do: attrs |> Map.new() |> normalize()

  defp normalize(attrs) when is_map(attrs) do
    Map.new(attrs, fn
      {key, value} when is_binary(key) -> {string_key(key), value}
      {key, value} -> {key, value}
    end)
  end

  defp string_key(key), do: Enum.find(@known_fields, key, &(Atom.to_string(&1) == key))

  defp present?(value) when is_binary(value), do: String.trim(value) != ""
  defp present?(value) when is_list(value), do: value != []
  defp present?(value), do: not is_nil(value)
end
