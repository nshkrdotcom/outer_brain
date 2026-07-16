defmodule OuterBrain.Persistence.ProfilePolicy do
  @moduledoc """
  Persistence profile selection and preflight policy.
  """

  alias OuterBrain.Persistence.{OptionAccess, Repo, SchemaPreflight}

  @spec preflight(keyword() | map()) :: :ok | {:error, term()}
  def preflight(opts \\ []) do
    attrs = OptionAccess.to_map(opts)

    with :ok <- validate_durable_profile(attrs) do
      preflight_repo(attrs)
    end
  end

  @spec require_durable_profile(keyword() | map()) :: :ok | no_return()
  def require_durable_profile(opts) when is_list(opts) do
    opts |> OptionAccess.to_map() |> require_durable_profile()
  end

  def require_durable_profile(opts) when is_map(opts) do
    case validate_durable_profile(opts) do
      :ok ->
        :ok

      {:error, {:unsupported_persistence_tier, :outer_brain_persistence, profile}} ->
        raise ArgumentError,
              "outer_brain production persistence requires :durable_redacted, got: #{inspect(profile)}"
    end
  end

  @spec validate_durable_profile(keyword() | map()) :: :ok | {:error, term()}
  def validate_durable_profile(opts) when is_list(opts) do
    opts |> OptionAccess.to_map() |> validate_durable_profile()
  end

  def validate_durable_profile(opts) when is_map(opts) do
    case selected_profile(opts) do
      :durable_redacted ->
        :ok

      profile ->
        {:error, {:unsupported_persistence_tier, :outer_brain_persistence, profile}}
    end
  end

  @spec selected_profile(keyword() | map()) :: atom() | term()
  def selected_profile(opts) do
    attrs = OptionAccess.to_map(opts)
    missing = OptionAccess.missing()

    profile =
      case OptionAccess.value(attrs, :profile, missing) do
        ^missing ->
          OptionAccess.value(attrs, :persistence_profile, missing)

        value ->
          value
      end

    normalize_profile(profile)
  end

  defp normalize_profile("durable_redacted"), do: :durable_redacted
  defp normalize_profile(profile), do: profile

  defp preflight_repo(attrs) do
    repo = OptionAccess.value(attrs, :repo, Repo)

    case OptionAccess.value(attrs, :repo_mode, :running) do
      mode when mode in [:running, :owned, :external] -> SchemaPreflight.check(repo)
      :temporary -> temporary_preflight(repo, OptionAccess.value(attrs, :repo_options, []))
      mode -> {:error, {:unsupported_repo_preflight_mode, mode}}
    end
  end

  defp temporary_preflight(repo, repo_options) when is_list(repo_options) do
    case Process.whereis(repo) do
      pid when is_pid(pid) ->
        SchemaPreflight.check(repo)

      nil ->
        case repo.start_link(repo_options) do
          {:ok, pid} ->
            try do
              SchemaPreflight.check(repo)
            after
              GenServer.stop(pid)
            end

          {:error, _reason} ->
            {:error, :repository_unavailable}
        end
    end
  catch
    :exit, _reason -> {:error, :repository_unavailable}
  end

  defp temporary_preflight(_repo, _repo_options),
    do: {:error, {:invalid_repo_options, :outer_brain_persistence}}
end
