# `OuterBrain.Contracts.Fence`

Fence view projected from a lease.

# `t`

```elixir
@type t() :: %OuterBrain.Contracts.Fence{
  epoch: non_neg_integer(),
  holder: String.t(),
  lease_id: String.t(),
  session_id: String.t()
}
```

# `from_lease`

```elixir
@spec from_lease(OuterBrain.Contracts.Lease.t()) :: t()
```

# `newer_than?`

```elixir
@spec newer_than?(t(), t()) :: boolean()
```

---

*Consult [api-reference.md](api-reference.md) for complete listing*
