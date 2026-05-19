defmodule OuterBrain.Persistence.PostgresContainerTest do
  use ExUnit.Case, async: true

  alias OuterBrain.Persistence.{BoundedAwait, PostgresContainer}

  test "bounded await reports the last failed probe" do
    error =
      assert_raise RuntimeError, fn ->
        BoundedAwait.until!(
          label: "test readiness",
          timeout_ms: 1,
          interval_ms: 1,
          probe: fn -> {:error, %{output: "still closed", exit_status: 1}} end
        )
      end

    message = Exception.message(error)
    assert String.contains?(message, "test readiness")
    assert String.contains?(message, "still closed")
  end

  test "postgres container cleanup runs when readiness fails" do
    test_pid = self()

    runner = fn
      "docker", ["run" | _args], _opts ->
        {"container-phase25\n", 0}

      "docker", ["port", "container-phase25", "5432/tcp"], _opts ->
        {"127.0.0.1:15432\n", 0}

      "psql", _args, _opts ->
        {"database is not ready", 1}

      "docker", ["rm", "--force", "container-phase25"], _opts ->
        send(test_pid, :container_removed)
        {"container-phase25", 0}
    end

    error =
      assert_raise RuntimeError, fn ->
        PostgresContainer.start!("phase25",
          command_runner: runner,
          timeout_ms: 1,
          interval_ms: 1
        )
      end

    assert String.contains?(Exception.message(error), "database is not ready")
    assert_received :container_removed
  end
end
