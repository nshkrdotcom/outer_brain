defmodule OuterBrain.Prompting.ContextRenderer do
  @moduledoc """
  Behaviour for rendering admitted Context ABI packets into prompt payload refs.

  Renderers return refs and hashes only. Provider-native payload bodies remain
  behind owner-controlled artifact refs and are not projected through this API.
  """

  alias OuterBrain.ContextABI.{ContextPacket, Failure}

  @type render_profile :: %{
          required(:provider_family) => String.t(),
          required(:model_class) => String.t(),
          optional(:payload_mode) => :ref_only | :sealed_debug
        }

  @type rendered_prompt :: %{
          required(:prompt_artifact_ref) => String.t(),
          required(:provider_payload_ref) => String.t(),
          required(:provider_family) => String.t(),
          required(:message_count) => non_neg_integer(),
          required(:token_estimate) => non_neg_integer(),
          required(:payload_hash) => String.t(),
          optional(:trace_ref) => String.t()
        }

  @callback render(ContextPacket.t(), render_profile(), keyword()) ::
              {:ok, rendered_prompt()} | {:error, Failure.t()}

  defmodule Fixture do
    @moduledoc """
    Deterministic CI-safe renderer for Context ABI roundtrip proofs.
    """

    @behaviour OuterBrain.Prompting.ContextRenderer

    alias OuterBrain.ContextABI.{Canonical, ContextPacket, Failure}
    alias OuterBrain.TokenMeter

    @impl true
    def render(packet, profile, opts \\ [])

    def render(%ContextPacket{} = packet, profile, opts)
        when is_map(profile) and is_list(opts) do
      with {:ok, provider_family} <- required_profile_string(profile, :provider_family),
           {:ok, model_class} <- required_profile_string(profile, :model_class),
           :ok <- payload_mode(profile) do
        payload = payload_claim(packet, provider_family, model_class)
        payload_hash = Canonical.digest(payload)
        suffix = String.replace_prefix(payload_hash, "sha256:", "")
        token_estimate = token_estimate(packet, opts)

        {:ok,
         %{
           prompt_artifact_ref: "prompt-artifact://#{suffix}",
           provider_payload_ref: "provider-payload://#{suffix}",
           provider_family: provider_family,
           message_count: 2 + length(packet.memory_refs),
           token_estimate: token_estimate,
           payload_hash: payload_hash,
           trace_ref: packet.trace_ref
         }}
      end
    end

    def render(%ContextPacket{}, _profile, _opts) do
      failure("outer_brain.prompting.invalid_render_profile.v1", "render profile is invalid")
    end

    defp required_profile_string(profile, field) do
      case Map.get(profile, field) || Map.get(profile, Atom.to_string(field)) do
        value when is_binary(value) and value != "" ->
          {:ok, value}

        _other ->
          failure("outer_brain.prompting.invalid_render_profile.v1", "render profile is invalid")
      end
    end

    defp payload_mode(profile) do
      case Map.get(profile, :payload_mode, Map.get(profile, "payload_mode", :ref_only)) do
        mode when mode in [:ref_only, :sealed_debug, "ref_only", "sealed_debug"] ->
          :ok

        _other ->
          failure("outer_brain.prompting.payload_mode_denied.v1", "payload mode is not allowed")
      end
    end

    defp payload_claim(%ContextPacket{} = packet, provider_family, model_class) do
      %{
        context_packet_ref: packet.context_packet_ref,
        packet_hash: packet.packet_hash,
        provider_family: provider_family,
        model_class: model_class,
        memory_ref_count: length(packet.memory_refs),
        route_policy_ref: packet.route_policy_ref,
        trace_ref: packet.trace_ref
      }
    end

    defp token_estimate(%ContextPacket{} = packet, opts) do
      prompt_tokens =
        Keyword.get(opts, :prompt_tokens, 32 + length(packet.memory_refs) * 8)

      counts = %TokenMeter.TokenCounts{
        prompt_tokens: prompt_tokens,
        completion_tokens: 0,
        cache_read_tokens: 0,
        cache_write_tokens: 0
      }

      TokenMeter.total_tokens(counts)
    end

    defp failure(reason_code, safe_message) do
      {:ok, failure} =
        Failure.new(%{
          owner: :outer_brain,
          reason_code: reason_code,
          safe_message: safe_message
        })

      {:error, failure}
    end
  end
end
