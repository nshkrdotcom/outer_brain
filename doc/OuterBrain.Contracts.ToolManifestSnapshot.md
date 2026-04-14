# `OuterBrain.Contracts.ToolManifestSnapshot`

Durable snapshot of the tool manifest presented to a model turn.

# `route_metadata`

```elixir
@type route_metadata() :: %{
  :description =&gt; String.t(),
  :input_schema_hash =&gt; String.t(),
  optional(:examples) =&gt; [map()]
}
```

# `t`

```elixir
@type t() :: %OuterBrain.Contracts.ToolManifestSnapshot{
  compiled_at: DateTime.t(),
  manifest_id: String.t(),
  routes: %{optional(String.t()) =&gt; route_metadata()},
  schema_hash: String.t(),
  version: String.t()
}
```

# `new`

```elixir
@spec new(map()) :: {:ok, t()} | {:error, term()}
```

# `route_names`

```elixir
@spec route_names(t()) :: [String.t()]
```

# `selection_valid?`

```elixir
@spec selection_valid?(t(), map()) :: :ok | {:error, term()}
```

---

*Consult [api-reference.md](api-reference.md) for complete listing*
