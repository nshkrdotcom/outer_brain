defmodule OuterBrain.Persistence.PostgresContainer do
  @moduledoc false

  @image System.get_env("OUTER_BRAIN_TEST_POSTGRES_IMAGE") || "postgres:16-alpine"
  @database "outer_brain_test"
  @password "postgres"
  @username "postgres"

  def start!(label, opts \\ []) when is_binary(label) and is_list(opts) do
    command_runner = Keyword.get(opts, :command_runner, &System.cmd/3)

    {output, 0} =
      command_runner.(
        "docker",
        [
          "run",
          "--detach",
          "--rm",
          "--label",
          "outer_brain_test=#{label}",
          "--env",
          "POSTGRES_DB=#{@database}",
          "--env",
          "POSTGRES_PASSWORD=#{@password}",
          "--env",
          "POSTGRES_USER=#{@username}",
          "--publish",
          "127.0.0.1::5432",
          @image
        ],
        stderr_to_stdout: true
      )

    container_id = String.trim(output)
    port = host_port!(container_id, command_runner)

    try do
      wait_until_ready!(port, command_runner, opts)
    rescue
      exception ->
        stop!(%{container_id: container_id}, command_runner: command_runner)
        reraise exception, __STACKTRACE__
    end

    %{container_id: container_id, port: port}
  end

  def stop!(%{container_id: container_id}, opts \\ []) do
    command_runner = Keyword.get(opts, :command_runner, &System.cmd/3)
    _ = command_runner.("docker", ["rm", "--force", container_id], stderr_to_stdout: true)
    :ok
  end

  def repo_config(port) when is_integer(port) do
    [
      hostname: "127.0.0.1",
      port: port,
      database: @database,
      username: @username,
      password: @password,
      pool: Ecto.Adapters.SQL.Sandbox,
      pool_size: 4,
      stacktrace: true,
      show_sensitive_data_on_connection_error: true
    ]
  end

  def migrations_path do
    Path.expand("../priv/repo/migrations", __DIR__)
  end

  def run_migrations!(repo) do
    previous_options = Code.compiler_options()
    Code.compiler_options(ignore_module_conflict: true)

    try do
      Ecto.Migrator.run(repo, migrations_path(), :up, all: true, log: false)
    after
      Code.compiler_options(previous_options)
    end
  end

  defp host_port!(container_id, command_runner) do
    {output, 0} =
      command_runner.("docker", ["port", container_id, "5432/tcp"], stderr_to_stdout: true)

    output
    |> String.trim()
    |> String.split(":")
    |> List.last()
    |> String.to_integer()
  end

  defp wait_until_ready!(port, command_runner, opts) do
    OuterBrain.Persistence.BoundedAwait.until!(
      label: "dockerized Postgres on port #{port}",
      timeout_ms: Keyword.get(opts, :timeout_ms, 10_000),
      interval_ms: Keyword.get(opts, :interval_ms, 250),
      probe: fn -> postgres_ready?(port, command_runner) end
    )
  end

  defp postgres_ready?(port, command_runner) do
    case command_runner.(
           "psql",
           [
             "--host",
             "127.0.0.1",
             "--port",
             Integer.to_string(port),
             "--username",
             @username,
             "--dbname",
             @database,
             "--command",
             "SELECT 1"
           ],
           env: [{"PGPASSWORD", @password}],
           stderr_to_stdout: true
         ) do
      {_output, 0} ->
        :ok

      {output, exit_status} ->
        {:error, %{exit_status: exit_status, output: String.trim(output)}}
    end
  end
end
