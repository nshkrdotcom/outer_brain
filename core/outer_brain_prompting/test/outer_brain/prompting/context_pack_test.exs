defmodule OuterBrain.Prompting.ContextPackTest do
  use ExUnit.Case, async: false

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

  defmodule AmbientAdapter do
    @behaviour OuterBrain.Prompting.ContextAdapter

    @impl true
    def fetch_fragments(request, runtime_binding) do
      send(runtime_binding["test_pid"], {:ambient_context_adapter, request, runtime_binding})

      {:ok,
       [
         %{
           fragment_id: "fragment-ambient",
           content: %{"summary" => "Ambient app env memory"},
           provenance: %{"external_system_ref" => "memory://ambient/app-env"},
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

  test "rejects context fragments before append when context budget is exhausted" do
    frame = SemanticFrame.seed("session_delta", "answer with retrieved context")

    pack =
      ContextPack.build(
        frame,
        ["turn_1"],
        trace_id: "bbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbb",
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
        adapter_registry: %{"read_only_probe" => ReadOnlyProbeAdapter},
        context_budget: %{
          budget_ref: "budget://phase5/m8/local-no-spend-inference",
          budget_scope: "subject://session_delta",
          max_context_bytes: 1,
          current_context_bytes: 0,
          enforcement_point: :tool_result_append
        }
      )

    assert_receive {:context_adapter_request, _request, _runtime_binding}
    assert pack.fragments == []
    assert pack.context_budget.decision == :reject_context_append
    assert pack.context_budget.enforcement_point == :tool_result_append
    assert pack.context_budget.append_context_bytes > pack.context_budget.max_context_bytes
  end

  test "allows context fragments when projected context stays within budget" do
    frame = SemanticFrame.seed("session_epsilon", "answer with retrieved context")

    pack =
      ContextPack.build(
        frame,
        ["turn_1"],
        trace_id: "cccccccccccccccccccccccccccccccc",
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
        adapter_registry: %{"read_only_probe" => ReadOnlyProbeAdapter},
        context_budget: %{
          budget_ref: "budget://phase5/m8/local-no-spend-inference",
          budget_scope: "subject://session_epsilon",
          max_context_bytes: 1_000_000,
          current_context_bytes: 0,
          enforcement_point: :tool_result_append
        }
      )

    assert_receive {:context_adapter_request, _request, _runtime_binding}
    assert [_fragment] = pack.fragments
    assert pack.context_budget.decision == :allow
    assert pack.context_budget.projected_context_bytes <= pack.context_budget.max_context_bytes
  end

  test "ignores ambient application env adapter registry for governed context packs" do
    previous_registry = Application.get_env(:outer_brain_prompting, :context_adapters)
    Application.put_env(:outer_brain_prompting, :context_adapters, %{"ambient" => AmbientAdapter})

    on_exit(fn ->
      restore_app_env(:outer_brain_prompting, :context_adapters, previous_registry)
    end)

    frame = SemanticFrame.seed("session_zeta", "answer with ambient memory blocked")

    pack =
      ContextPack.build(
        frame,
        ["turn_1"],
        trace_id: "dddddddddddddddddddddddddddddddd",
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
            "adapter_key" => "ambient",
            "config" => %{"workspace" => "main"},
            "test_pid" => self()
          }
        }
      )

    assert pack.fragments == []

    assert [%{adapter_key: "ambient", error: {:adapter_not_registered, "ambient"}}] =
             pack.context_sources

    refute_received {:ambient_context_adapter, _request, _runtime_binding}
  end

  test "keeps standalone application env adapter registry behind explicit opt in" do
    previous_registry = Application.get_env(:outer_brain_prompting, :context_adapters)
    Application.put_env(:outer_brain_prompting, :context_adapters, %{"ambient" => AmbientAdapter})

    on_exit(fn ->
      restore_app_env(:outer_brain_prompting, :context_adapters, previous_registry)
    end)

    frame = SemanticFrame.seed("session_eta", "answer with standalone memory")

    pack =
      ContextPack.build(
        frame,
        ["turn_1"],
        trace_id: "eeeeeeeeeeeeeeeeeeeeeeeeeeeeeeee",
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
            "adapter_key" => "ambient",
            "config" => %{"workspace" => "main"},
            "test_pid" => self()
          }
        },
        standalone_application_env?: true
      )

    assert_receive {:ambient_context_adapter, _request, _runtime_binding}
    assert [fragment] = pack.fragments
    assert fragment.provenance["adapter_key"] == "ambient"
    assert fragment.provenance["external_system_ref"] == "memory://ambient/app-env"
  end

  defp stringify_keys(map) do
    Map.new(map, fn {key, value} -> {to_string(key), value} end)
  end

  defp restore_app_env(app, key, nil), do: Application.delete_env(app, key)
  defp restore_app_env(app, key, value), do: Application.put_env(app, key, value)
end
