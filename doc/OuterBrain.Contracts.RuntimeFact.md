# `OuterBrain.Contracts.RuntimeFact`

Durable lower-runtime fact consumed by the semantic layer.

# `kind`

```elixir
@type kind() ::
  :accepted_downstream
  | :execution_completed
  | :publication_failed
  | :pressure
  | :reconnect
  | :lane_churn
```

# `t`

```elixir
@type t() :: %OuterBrain.Contracts.RuntimeFact{
  causal_unit_id: String.t(),
  fact_id: String.t(),
  kind: kind(),
  payload: map()
}
```

# `kinds`

```elixir
@spec kinds() :: [kind()]
```

# `new`

```elixir
@spec new(map()) :: {:ok, t()} | {:error, term()}
```

# `wake_key`

```elixir
@spec wake_key(t()) :: String.t()
```

---

*Consult [api-reference.md](api-reference.md) for complete listing*
