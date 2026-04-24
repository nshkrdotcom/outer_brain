defmodule OuterBrain.Journal.Tables do
  @moduledoc """
  Table-shaped rows for the semantic journal.
  """

  defmodule SemanticSessionLeaseRecord do
    @moduledoc """
    Durable lease ownership row for a semantic session.
    """

    defstruct [:row_id, :session_id, :holder, :lease_id, :epoch, :expires_at]

    @type t :: %__MODULE__{
            row_id: String.t(),
            session_id: String.t(),
            holder: String.t(),
            lease_id: String.t(),
            epoch: non_neg_integer(),
            expires_at: DateTime.t()
          }

    def new(%{
          row_id: row_id,
          session_id: session_id,
          holder: holder,
          lease_id: lease_id,
          epoch: epoch,
          expires_at: %DateTime{} = expires_at
        })
        when is_binary(row_id) and is_binary(session_id) and is_binary(holder) and
               is_binary(lease_id) and is_integer(epoch) and epoch >= 0 do
      {:ok,
       %__MODULE__{
         row_id: row_id,
         session_id: session_id,
         holder: holder,
         lease_id: lease_id,
         epoch: epoch,
         expires_at: expires_at
       }}
    end

    def new(_attrs), do: {:error, :invalid_semantic_session_lease_record}
  end

  defmodule SemanticJournalEntryRecord do
    @moduledoc """
    Durable semantic journal row captured for restart and replay analysis.
    """

    defstruct [:entry_id, :session_id, :causal_unit_id, :entry_type, :recorded_at, payload: %{}]

    @type t :: %__MODULE__{
            entry_id: String.t(),
            session_id: String.t(),
            causal_unit_id: String.t(),
            entry_type: String.t(),
            recorded_at: DateTime.t(),
            payload: map()
          }

    def new(
          %{
            entry_id: entry_id,
            session_id: session_id,
            causal_unit_id: causal_unit_id,
            entry_type: entry_type,
            recorded_at: %DateTime{} = recorded_at
          } = attrs
        )
        when is_binary(entry_id) and is_binary(session_id) and is_binary(causal_unit_id) and
               is_binary(entry_type) do
      payload = Map.get(attrs, :payload, %{})

      if is_map(payload) do
        {:ok,
         %__MODULE__{
           entry_id: entry_id,
           session_id: session_id,
           causal_unit_id: causal_unit_id,
           entry_type: entry_type,
           recorded_at: recorded_at,
           payload: payload
         }}
      else
        {:error, :invalid_semantic_journal_entry_record}
      end
    end

    def new(_attrs), do: {:error, :invalid_semantic_journal_entry_record}
  end

  defmodule SemanticFrameRecord do
    @moduledoc false

    defstruct [:frame_id, :session_id, :objective, unresolved_questions: [], commitments: []]

    def new(%{frame_id: frame_id, session_id: session_id, objective: objective} = attrs)
        when is_binary(frame_id) and is_binary(session_id) and is_binary(objective) do
      {:ok,
       %__MODULE__{
         frame_id: frame_id,
         session_id: session_id,
         objective: objective,
         unresolved_questions: Map.get(attrs, :unresolved_questions, []),
         commitments: Map.get(attrs, :commitments, [])
       }}
    end

    def new(_attrs), do: {:error, :invalid_semantic_frame_record}
  end

  defmodule ContextPackRecord do
    @moduledoc false

    defstruct [:context_pack_id, :session_id, refs: [], body: %{}]

    def new(%{context_pack_id: context_pack_id, session_id: session_id} = attrs)
        when is_binary(context_pack_id) and is_binary(session_id) do
      {:ok,
       %__MODULE__{
         context_pack_id: context_pack_id,
         session_id: session_id,
         refs: Map.get(attrs, :refs, []),
         body: Map.get(attrs, :body, %{})
       }}
    end

    def new(_attrs), do: {:error, :invalid_context_pack_record}
  end

  defmodule StrategyProfileRecord do
    @moduledoc false

    defstruct [:strategy_profile_id, :session_id, :name, body: %{}]

    def new(
          %{strategy_profile_id: strategy_profile_id, session_id: session_id, name: name} = attrs
        )
        when is_binary(strategy_profile_id) and is_binary(session_id) and is_atom(name) do
      {:ok,
       %__MODULE__{
         strategy_profile_id: strategy_profile_id,
         session_id: session_id,
         name: name,
         body: Map.get(attrs, :body, %{})
       }}
    end

    def new(_attrs), do: {:error, :invalid_strategy_profile_record}
  end

  defmodule ToolManifestRecord do
    @moduledoc false

    defstruct [:manifest_id, :session_id, :schema_hash, :version, :compiled_at, routes: %{}]

    def new(%{
          manifest_id: manifest_id,
          session_id: session_id,
          schema_hash: schema_hash,
          version: version,
          compiled_at: %DateTime{} = compiled_at,
          routes: routes
        })
        when is_binary(manifest_id) and is_binary(session_id) and is_binary(schema_hash) and
               is_binary(version) and is_map(routes) do
      {:ok,
       %__MODULE__{
         manifest_id: manifest_id,
         session_id: session_id,
         schema_hash: schema_hash,
         version: version,
         compiled_at: compiled_at,
         routes: routes
       }}
    end

    def new(_attrs), do: {:error, :invalid_tool_manifest_record}
  end

  defmodule QualityCheckpointRecord do
    @moduledoc false

    defstruct [:checkpoint_id, :session_id, :stage, :outcome, notes: []]

    def new(
          %{
            checkpoint_id: checkpoint_id,
            session_id: session_id,
            stage: stage,
            outcome: outcome
          } = attrs
        )
        when is_binary(checkpoint_id) and is_binary(session_id) and is_atom(stage) and
               is_atom(outcome) do
      {:ok,
       %__MODULE__{
         checkpoint_id: checkpoint_id,
         session_id: session_id,
         stage: stage,
         outcome: outcome,
         notes: Map.get(attrs, :notes, [])
       }}
    end

    def new(_attrs), do: {:error, :invalid_quality_checkpoint_record}
  end

  defmodule ReplyPublicationRecord do
    @moduledoc """
    Durable publication row describing provisional or final user-facing output.
    """

    alias OuterBrain.Contracts.ReplyBodyBoundary

    defstruct [:publication_id, :causal_unit_id, :phase, :state, :dedupe_key, :body, :body_ref]

    @type t :: %__MODULE__{
            publication_id: String.t(),
            causal_unit_id: String.t(),
            phase: :provisional | :final,
            state: :pending | :published | :suppressed,
            dedupe_key: String.t(),
            body: String.t(),
            body_ref: ReplyBodyBoundary.body_ref()
          }

    def new(%{
          publication_id: publication_id,
          causal_unit_id: causal_unit_id,
          phase: phase,
          state: state,
          dedupe_key: dedupe_key,
          body: body,
          body_ref: body_ref
        })
        when is_binary(publication_id) and is_binary(causal_unit_id) and
               phase in [:provisional, :final] and
               state in [:pending, :published, :suppressed] and is_binary(dedupe_key) and
               is_binary(body) and is_map(body_ref) do
      with true <- ReplyBodyBoundary.valid_preview?(body),
           :ok <- ReplyBodyBoundary.validate_ref(body_ref, causal_unit_id, phase, dedupe_key) do
        {:ok,
         %__MODULE__{
           publication_id: publication_id,
           causal_unit_id: causal_unit_id,
           phase: phase,
           state: state,
           dedupe_key: dedupe_key,
           body: body,
           body_ref: body_ref
         }}
      else
        _reason -> {:error, :invalid_reply_publication_record}
      end
    end

    def new(_attrs), do: {:error, :invalid_reply_publication_record}
  end

  defmodule RecoveryTaskRecord do
    @moduledoc """
    Durable recovery-work row used by restart authority reconstruction.
    """

    defstruct [:task_id, :session_id, :reason, :status]

    @type t :: %__MODULE__{
            task_id: String.t(),
            session_id: String.t(),
            reason: atom(),
            status: :pending | :running | :done
          }

    def new(%{task_id: task_id, session_id: session_id, reason: reason, status: status})
        when is_binary(task_id) and is_binary(session_id) and is_atom(reason) and
               status in [:pending, :running, :done] do
      {:ok, %__MODULE__{task_id: task_id, session_id: session_id, reason: reason, status: status}}
    end

    def new(_attrs), do: {:error, :invalid_recovery_task_record}
  end
end
