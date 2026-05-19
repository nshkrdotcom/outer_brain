defmodule OuterBrain.Persistence.TenantOptions do
  @moduledoc false

  alias OuterBrain.Persistence.Repo

  @spec repo(keyword()) :: module()
  def repo(opts), do: Keyword.get(opts, :repo, Repo)

  @spec tenant_id!(keyword()) :: String.t()
  def tenant_id!(opts) do
    case Keyword.get(opts, :tenant_id) do
      tenant_id when is_binary(tenant_id) and tenant_id != "" ->
        tenant_id

      _other ->
        raise ArgumentError, "outer_brain persistence calls require :tenant_id"
    end
  end

  @spec recorded_at(keyword()) :: DateTime.t()
  def recorded_at(opts), do: Keyword.get(opts, :recorded_at, DateTime.utc_now())
end
