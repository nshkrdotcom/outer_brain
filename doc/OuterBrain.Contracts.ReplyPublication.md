# `OuterBrain.Contracts.ReplyPublication`

Durable reply publication state for semantic output.

# `phase`

```elixir
@type phase() :: :provisional | :final
```

# `state`

```elixir
@type state() :: :pending | :published | :suppressed
```

# `t`

```elixir
@type t() :: %OuterBrain.Contracts.ReplyPublication{
  body: String.t(),
  causal_unit_id: String.t(),
  dedupe_key: String.t(),
  phase: phase(),
  publication_id: String.t(),
  state: state()
}
```

# `new`

```elixir
@spec new(map()) :: {:ok, t()} | {:error, term()}
```

# `valid_phase?`

```elixir
@spec valid_phase?(term()) :: boolean()
```

# `valid_state?`

```elixir
@spec valid_state?(term()) :: boolean()
```

---

*Consult [api-reference.md](api-reference.md) for complete listing*
