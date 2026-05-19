defmodule OuterBrain.Persistence.BoundedAwait do
  @moduledoc false

  @spec until!(keyword()) :: :ok
  def until!(opts) when is_list(opts) do
    label = Keyword.fetch!(opts, :label)
    probe = Keyword.fetch!(opts, :probe)
    timeout_ms = Keyword.get(opts, :timeout_ms, 10_000)
    interval_ms = Keyword.get(opts, :interval_ms, 250)
    deadline_ms = System.monotonic_time(:millisecond) + timeout_ms

    await!(label, probe, interval_ms, deadline_ms, nil)
  end

  defp await!(label, probe, interval_ms, deadline_ms, last_result) do
    case probe.() do
      :ok ->
        :ok

      {:error, reason} ->
        retry_or_raise!(label, probe, interval_ms, deadline_ms, {:error, reason})

      other ->
        retry_or_raise!(label, probe, interval_ms, deadline_ms, other || last_result)
    end
  end

  defp retry_or_raise!(label, probe, interval_ms, deadline_ms, last_result) do
    if System.monotonic_time(:millisecond) >= deadline_ms do
      raise "#{label} did not become ready before timeout; last_result=#{inspect(last_result)}"
    else
      Process.sleep(interval_ms)
      await!(label, probe, interval_ms, deadline_ms, last_result)
    end
  end
end
