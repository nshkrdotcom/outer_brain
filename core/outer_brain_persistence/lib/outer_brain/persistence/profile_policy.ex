defmodule OuterBrain.Persistence.ProfilePolicy do
  @moduledoc """
  Persistence profile selection and preflight policy.
  """

  alias OuterBrain.Persistence.OptionAccess

  @supported_memory_profiles [:mickey_mouse, :memory_debug, :off]

  @spec preflight(keyword() | map()) :: :ok | {:error, term()}
  def preflight(opts \\ []) do
    attrs = OptionAccess.to_map(opts)

    case selected_profile(attrs) do
      profile when profile in @supported_memory_profiles ->
        :ok

      :integration_postgres ->
        require_migration_proof(attrs)

      other ->
        {:error, {:unsupported_persistence_tier, :outer_brain_persistence, other}}
    end
  end

  @spec selected_profile(keyword() | map()) :: atom() | term()
  def selected_profile(opts) do
    attrs = OptionAccess.to_map(opts)
    missing = OptionAccess.missing()

    profile =
      case OptionAccess.value(attrs, :profile, missing) do
        ^missing ->
          OptionAccess.value(attrs, :persistence_profile, :mickey_mouse)

        value ->
          value
      end

    normalize_profile(profile)
  end

  defp normalize_profile("mickey_mouse"), do: :mickey_mouse
  defp normalize_profile("memory_debug"), do: :memory_debug
  defp normalize_profile("off"), do: :off
  defp normalize_profile("integration_postgres"), do: :integration_postgres
  defp normalize_profile(profile), do: profile

  defp require_migration_proof(attrs) do
    case OptionAccess.value(attrs, :migration_proof, OptionAccess.missing()) do
      :present -> :ok
      true -> :ok
      paths when is_list(paths) and paths != [] -> :ok
      _missing_or_false -> {:error, {:missing_migration_proof, :outer_brain_persistence}}
    end
  end
end
