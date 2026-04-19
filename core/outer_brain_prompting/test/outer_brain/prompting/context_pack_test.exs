defmodule OuterBrain.Prompting.ContextPackTest do
  use ExUnit.Case, async: true

  alias OuterBrain.Core.SemanticFrame
  alias OuterBrain.Prompting.ContextPack

  defmodule SuccessfulAdapter do
    @behaviour OuterBrain.Prompting.ContextAdapter

    @impl true
    def fetch_fragments(request, runtime_binding) do
      {:ok,
       [
         %{
           fragment_id: "fragment-1",
           schema_ref: request.schema_ref,
           schema_version: 1,
           content: %{"summary" => "Relevant memory"},
           provenance: %{"workspace" => get_in(runtime_binding, ["config", "workspace"])},
           staleness: %{"class" => "fresh"},
           metadata: %{"rank" => 1}
         },
         %{
           fragment_id: "fragment-2",
           content: %{"summary" => "Second memory"},
           provenance: %{},
           staleness: %{"class" => "fresh"},
           metadata: %{"rank" => 2}
         }
       ]}
    end
  end

  defmodule SlowAdapter do
    @behaviour OuterBrain.Prompting.ContextAdapter

    @impl true
    def fetch_fragments(_request, _runtime_binding) do
      Process.sleep(25)
      {:ok, []}
    end
  end

  defmodule ReadOnlyProbeAdapter do
    @behaviour OuterBrain.Prompting.ContextAdapter

    @impl true
    def fetch_fragments(request, runtime_binding) do
      send(runtime_binding["test_pid"], {:context_adapter_request, request, runtime_binding})

      {:ok,
       [
         %{
           fragment_id: "fragment-read-only",
           content: %{"summary" => "Read-only workspace fact"},
           provenance: %{"external_system_ref" => "memory://workspace/main"},
           staleness: %{"class" => "fresh"},
           metadata: %{"rank" => 1}
         }
       ]}
    end
  end

  test "builds a context pack with bounded adapter fragments and provenance" do
    frame =
      "session_alpha"
      |> SemanticFrame.seed("answer the user")
      |> SemanticFrame.record_commitment("I will verify the workspace")

    pack =
      ContextPack.build(
        frame,
        ["turn_1", "artifact_1"],
        mode: :reply,
        trace_id: "0123456789abcdef0123456789abcdef",
        context_sources: [
          %{
            source_ref: "workspace_memory",
            binding_key: "shared_memory",
            usage_phase: :retrieval,
            required?: false,
            timeout_ms: 20,
            schema_ref: "context/workspace_memory",
            max_fragments: 1,
            merge_strategy: :ranked_append
          }
        ],
        context_bindings: %{
          "shared_memory" => %{
            "adapter_key" => "mem0_context",
            "config" => %{"workspace" => "default"},
            "timeout_ms" => 20
          }
        },
        adapter_registry: %{"mem0_context" => SuccessfulAdapter}
      )

    assert pack.trace_id == "0123456789abcdef0123456789abcdef"
    assert [%{"fragment_id" => _}] = Enum.map(pack.fragments, &stringify_keys/1)
    assert length(pack.fragments) == 1

    assert [
             %{
               source_ref: "workspace_memory",
               binding_key: "shared_memory",
               status: :ok,
               adapter_key: "mem0_context",
               fragment_count: 1
             }
           ] = pack.context_sources

    [fragment] = pack.fragments
    assert fragment.fragment_id == "fragment-1"
    assert fragment.schema_ref == "context/workspace_memory"
    assert fragment.provenance["source_ref"] == "workspace_memory"
    assert fragment.provenance["binding_key"] == "shared_memory"
    assert fragment.provenance["adapter_key"] == "mem0_context"
    assert fragment.provenance["workspace"] == "default"
  end

  test "degrades context sources when trace propagation or adapter timing is missing" do
    frame = SemanticFrame.seed("session_beta", "repair the session")

    missing_trace_pack =
      ContextPack.build(
        frame,
        ["turn_1"],
        context_sources: [
          %{
            source_ref: "workspace_memory",
            binding_key: "shared_memory",
            usage_phase: :retrieval,
            required?: true,
            timeout_ms: 5,
            max_fragments: 2,
            merge_strategy: :append
          }
        ],
        context_bindings: %{
          "shared_memory" => %{
            "adapter_key" => "slow_memory",
            "config" => %{}
          }
        },
        adapter_registry: %{"slow_memory" => SlowAdapter}
      )

    assert missing_trace_pack.fragments == []
    assert hd(missing_trace_pack.context_sources).status == :degraded
    assert hd(missing_trace_pack.context_sources).error == :missing_trace_id

    timeout_pack =
      ContextPack.build(
        frame,
        ["turn_1"],
        trace_id: "fedcba9876543210fedcba9876543210",
        context_sources: [
          %{
            source_ref: "workspace_memory",
            binding_key: "shared_memory",
            usage_phase: :retrieval,
            required?: false,
            timeout_ms: 5,
            max_fragments: 2,
            merge_strategy: :append
          }
        ],
        context_bindings: %{
          "shared_memory" => %{
            "adapter_key" => "slow_memory",
            "config" => %{},
            "timeout_ms" => 5
          }
        },
        adapter_registry: %{"slow_memory" => SlowAdapter}
      )

    assert timeout_pack.fragments == []
    assert hd(timeout_pack.context_sources).status == :degraded
    assert hd(timeout_pack.context_sources).error == :timeout
  end

  test "context adapters receive a read-only request and preserve provenance" do
    frame = SemanticFrame.seed("session_gamma", "answer with retrieved context")

    pack =
      ContextPack.build(
        frame,
        ["turn_1"],
        trace_id: "aaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaa",
        context_sources: [
          %{
            source_ref: "workspace_memory",
            binding_key: "shared_memory",
            usage_phase: :retrieval,
            required?: true,
            timeout_ms: 20,
            schema_ref: "context/workspace_memory",
            max_fragments: 1
          }
        ],
        context_bindings: %{
          "shared_memory" => %{
            "adapter_key" => "read_only_probe",
            "config" => %{"workspace" => "main"},
            "test_pid" => self()
          }
        },
        adapter_registry: %{"read_only_probe" => ReadOnlyProbeAdapter}
      )

    assert_receive {:context_adapter_request, request, runtime_binding}

    assert Enum.sort(Map.keys(request)) == [
             :binding_key,
             :commitments,
             :max_fragments,
             :mode,
             :objective,
             :refs,
             :schema_ref,
             :session_id,
             :source_ref,
             :trace_id,
             :unresolved_questions,
             :usage_phase
           ]

    refute Map.has_key?(request, :write_intent)
    refute Map.has_key?(request, :mutation)
    assert runtime_binding["config"] == %{"workspace" => "main"}

    assert [fragment] = pack.fragments
    assert fragment.provenance["source_ref"] == "workspace_memory"
    assert fragment.provenance["binding_key"] == "shared_memory"
    assert fragment.provenance["adapter_key"] == "read_only_probe"
    assert fragment.provenance["external_system_ref"] == "memory://workspace/main"
  end

  defp stringify_keys(map) do
    Map.new(map, fn {key, value} -> {to_string(key), value} end)
  end
end
