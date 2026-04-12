unless Code.ensure_loaded?(OuterBrain.Build.WeldContract) do
  Code.require_file("weld_contract.exs", __DIR__)
end

OuterBrain.Build.WeldContract.manifest()
