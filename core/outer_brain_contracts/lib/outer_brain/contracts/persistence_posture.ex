defmodule OuterBrain.Contracts.PersistencePosture do
  @moduledoc """
  Ref-only persistence posture for OuterBrain semantic evidence.

  The posture describes storage and capture behavior for semantic contracts. It
  does not change semantic selection, prompt provenance, duplicate
  suppression, publication, or failure-journal semantics.
  """

  @profiles %{
    mickey_mouse: %{
      persistence_profile_ref: "persistence-profile://mickey-mouse",
      persistence_tier_ref: "persistence-tier://memory-ephemeral",
      capture_level_ref: "capture-level://off",
      store_set_ref: "store-set://outer-brain/memory-ref-only",
      retention_policy_ref: "retention://lost-on-process-exit",
      debug_tap_ref: "debug-tap://noop",
      durable?: false,
      retained?: true
    },
    memory_debug: %{
      persistence_profile_ref: "persistence-profile://memory-debug",
      persistence_tier_ref: "persistence-tier://memory-ephemeral",
      capture_level_ref: "capture-level://redacted-debug",
      store_set_ref: "store-set://outer-brain/redacted-memory-ring",
      retention_policy_ref: "retention://lost-on-process-exit",
      debug_tap_ref: "debug-tap://memory-ring",
      durable?: false,
      retained?: true
    },
    durable_redacted: %{
      persistence_profile_ref: "persistence-profile://outer-brain-durable-redacted",
      persistence_tier_ref: "persistence-tier://durable",
      capture_level_ref: "capture-level://redacted-summary",
      store_set_ref: "store-set://outer-brain/durable-redacted",
      retention_policy_ref: "retention://operator-configured",
      debug_tap_ref: "debug-tap://noop",
      durable?: true,
      retained?: true
    }
  }

  @components %{
    semantic_session: "component://outer-brain/semantic-session",
    prompt_provenance: "component://outer-brain/prompt-provenance",
    context_fragment: "component://outer-brain/context-fragment",
    context_pack: "component://outer-brain/context-pack",
    prompt_pack: "component://outer-brain/prompt-pack",
    semantic_failure: "component://outer-brain/semantic-failure",
    publication_state: "component://outer-brain/publication-state",
    publication_bridge: "component://outer-brain/publication-bridge",
    projection_publication: "component://outer-brain/projection-publication",
    duplicate_suppression: "component://outer-brain/duplicate-suppression",
    authority_evidence: "component://outer-brain/authority-evidence",
    journal: "component://outer-brain/journal"
  }

  @profile_lookup %{
    "mickey_mouse" => :mickey_mouse,
    "memory_debug" => :memory_debug,
    "durable_redacted" => :durable_redacted
  }

  @type component ::
          :semantic_session
          | :prompt_provenance
          | :context_fragment
          | :context_pack
          | :prompt_pack
          | :semantic_failure
          | :publication_state
          | :publication_bridge
          | :projection_publication
          | :duplicate_suppression
          | :authority_evidence
          | :journal

  @type t :: %{
          component_ref: String.t(),
          persistence_profile_ref: String.t(),
          persistence_tier_ref: String.t(),
          capture_level_ref: String.t(),
          store_set_ref: String.t(),
          retention_policy_ref: String.t(),
          debug_tap_ref: String.t(),
          persistence_receipt_ref: String.t(),
          durable?: boolean(),
          retained?: boolean(),
          raw_prompt_persistence?: false,
          raw_provider_payload_persistence?: false
        }

  @spec memory(component()) :: t()
  def memory(component), do: resolve(component, %{})

  @spec durable(component()) :: t()
  def durable(component), do: resolve(component, %{persistence_profile: :durable_redacted})

  @spec resolve(component(), map() | keyword() | nil) :: t()
  def resolve(component, attrs \\ %{}) do
    attrs = normalize_attrs(attrs)

    case Map.get(attrs, :persistence_posture) do
      posture when is_map(posture) ->
        posture
        |> normalize_attrs()
        |> Map.merge(base(component, profile_from_attrs(posture)), fn _key, value, _base ->
          value
        end)
        |> ensure_component(component)

      _other ->
        base(component, profile_from_attrs(attrs))
    end
  end

  @spec debug_tap_failed(map()) :: map()
  def debug_tap_failed(posture) when is_map(posture) do
    posture
    |> Map.put(:debug_tap_result, :failed_non_mutating)
    |> Map.put(:debug_sidecar_mutated_state?, false)
  end

  defp base(component, profile) do
    profile_values = Map.fetch!(@profiles, profile)
    component_ref = Map.fetch!(@components, component)

    profile_values
    |> Map.put(:component_ref, component_ref)
    |> Map.put(:persistence_receipt_ref, receipt_ref(component, profile))
    |> Map.put(:raw_prompt_persistence?, false)
    |> Map.put(:raw_provider_payload_persistence?, false)
  end

  defp ensure_component(posture, component) do
    posture
    |> Map.put_new(:component_ref, Map.fetch!(@components, component))
    |> Map.put_new(:persistence_receipt_ref, receipt_ref(component, :mickey_mouse))
    |> Map.put(:raw_prompt_persistence?, false)
    |> Map.put(:raw_provider_payload_persistence?, false)
  end

  defp profile_from_attrs(attrs) do
    attrs = normalize_attrs(attrs)

    attrs
    |> Map.get(:persistence_profile, Map.get(attrs, :persistence_profile_ref, :mickey_mouse))
    |> normalize_profile()
  end

  defp normalize_profile(profile) when is_atom(profile) and is_map_key(@profiles, profile),
    do: profile

  defp normalize_profile(profile) when is_binary(profile) do
    cond do
      Map.has_key?(@profile_lookup, profile) -> Map.fetch!(@profile_lookup, profile)
      String.contains?(profile, "memory-debug") -> :memory_debug
      String.contains?(profile, "durable") -> :durable_redacted
      true -> :mickey_mouse
    end
  end

  defp normalize_profile(_profile), do: :mickey_mouse

  defp normalize_attrs(nil), do: %{}
  defp normalize_attrs(attrs) when is_list(attrs), do: attrs |> Map.new() |> normalize_attrs()

  defp normalize_attrs(attrs) when is_map(attrs) do
    Map.new(attrs, fn
      {key, value} when is_binary(key) -> {string_key(key), value}
      {key, value} -> {key, value}
    end)
  end

  defp normalize_attrs(_attrs), do: %{}

  defp string_key("persistence_profile"), do: :persistence_profile
  defp string_key("persistence_profile_ref"), do: :persistence_profile_ref
  defp string_key("persistence_posture"), do: :persistence_posture
  defp string_key("retained?"), do: :retained?
  defp string_key("durable?"), do: :durable?
  defp string_key(key), do: key

  defp receipt_ref(component, profile) do
    "persistence-receipt://outer-brain/#{component}/#{profile}"
  end
end
