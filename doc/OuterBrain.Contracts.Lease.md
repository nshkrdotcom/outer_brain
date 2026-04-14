# `OuterBrain.Contracts.Lease`

Lease contract for one semantic-session owner.

# `t`

```elixir
@type t() :: %OuterBrain.Contracts.Lease{
  epoch: non_neg_integer(),
  expires_at: DateTime.t(),
  holder: String.t(),
  lease_id: String.t(),
  session_id: String.t()
}
```

# `expired?`

```elixir
@spec expired?(t(), DateTime.t()) :: boolean()
```

# `new`

```elixir
@spec new(map()) :: {:ok, t()} | {:error, term()}
```

---

*Consult [api-reference.md](api-reference.md) for complete listing*
