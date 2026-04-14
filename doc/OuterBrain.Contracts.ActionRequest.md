# `OuterBrain.Contracts.ActionRequest`

Structured request compiled from semantic intent after manifest validation.

# `t`

```elixir
@type t() :: %OuterBrain.Contracts.ActionRequest{
  args: map(),
  manifest_id: String.t(),
  provenance: map(),
  request_id: String.t(),
  route: String.t(),
  session_id: String.t()
}
```

# `new`

```elixir
@spec new(map()) :: {:ok, t()} | {:error, term()}
```

---

*Consult [api-reference.md](api-reference.md) for complete listing*
