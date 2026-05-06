defmodule OuterBrain.TokenMeterTest do
  use ExUnit.Case, async: true

  alias OuterBrain.TokenMeter

  test "creates a bounded token meter ref for known provider families" do
    assert {:ok, ref} =
             TokenMeter.token_meter_ref(%{
               meter_id: "meter://codex/default",
               provider_family: :codex_cli,
               model_ref: "model://codex/latest",
               tenant_ref: "tenant://a",
               installation_ref: "installation://a",
               revision: 1
             })

    assert ref.provider_family == :codex_cli
  end

  test "rejects unknown provider families and missing model refs" do
    assert {:error, {:unknown_token_meter_enum, :provider_family}} =
             TokenMeter.token_meter_ref(%{
               meter_id: "meter://unknown",
               provider_family: :unknown,
               model_ref: "model://x",
               tenant_ref: "tenant://a",
               installation_ref: "installation://a",
               revision: 1
             })

    assert {:error, {:missing_token_meter_ref, :model_ref}} =
             TokenMeter.token_meter_ref(%{
               meter_id: "meter://missing-model",
               provider_family: :codex_cli,
               tenant_ref: "tenant://a",
               installation_ref: "installation://a",
               revision: 1
             })
  end

  test "counts four bounded token classes and rejects provider invokers" do
    assert {:ok, ref} = token_meter_ref()

    assert {:ok, call} =
             TokenMeter.count_call(ref, %{
               call_ref: "call://one",
               operation_class: :prompt,
               excerpt_ref: "excerpt://prompt/hash",
               count_class: :measured,
               rollup_key: "workflow://a",
               prompt_tokens: 10,
               completion_tokens: 3,
               cache_read_tokens: 2,
               cache_write_tokens: 1
             })

    assert TokenMeter.total_tokens(call.token_counts) == 16

    assert {:error, {:raw_token_meter_payload_forbidden, :provider_invoker}} =
             TokenMeter.count_call(ref, %{
               call_ref: "call://provider-invoker",
               operation_class: :prompt,
               excerpt_ref: "excerpt://prompt/hash",
               count_class: :measured,
               rollup_key: "workflow://a",
               provider_invoker: fn -> :network end
             })
  end

  test "rolls up metered calls deterministically without double-counting omitted cache tokens" do
    assert {:ok, ref} = token_meter_ref()
    assert {:ok, first} = call(ref, "call://b", 4, 2)
    assert {:ok, second} = call(ref, "call://a", 1, 0)

    assert {:ok, rollup} = TokenMeter.rollup([first, second])

    assert rollup.call_refs == ["call://a", "call://b"]
    assert rollup.token_counts.prompt_tokens == 5
    assert rollup.token_counts.completion_tokens == 2
  end

  defp token_meter_ref do
    TokenMeter.token_meter_ref(%{
      meter_id: "meter://codex/default",
      provider_family: :codex_cli,
      model_ref: "model://codex/latest",
      tenant_ref: "tenant://a",
      installation_ref: "installation://a",
      revision: 1
    })
  end

  defp call(ref, call_ref, prompt_tokens, completion_tokens) do
    TokenMeter.count_call(ref, %{
      call_ref: call_ref,
      operation_class: :completion,
      excerpt_ref: "excerpt://#{call_ref}",
      count_class: :bounded_fixture,
      rollup_key: "workflow://a",
      prompt_tokens: prompt_tokens,
      completion_tokens: completion_tokens
    })
  end
end
