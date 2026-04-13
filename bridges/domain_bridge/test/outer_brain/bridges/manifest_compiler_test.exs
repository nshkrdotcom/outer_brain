defmodule OuterBrain.Bridges.ManifestCompilerTest do
  use ExUnit.Case, async: true

  alias OuterBrain.Bridges.ManifestCompiler

  test "route catalogs and model tool manifests are separate artifacts" do
    assert {:ok, snapshot} =
             ManifestCompiler.compile(
               [
                 %{
                   name: "reply_to_user",
                   description: "Reply to the user",
                   input_schema_hash: "schema_reply"
                 }
               ],
               manifest_id: "manifest_1",
               version: "1",
               compiled_at: DateTime.from_unix!(1_800_000_600)
             )

    assert snapshot.manifest_id == "manifest_1"
    assert Map.has_key?(snapshot.routes, "reply_to_user")
  end

  test "compiles a tool manifest snapshot from jido_domain route sources" do
    assert {:ok, snapshot} =
             ManifestCompiler.compile_domain_routes([
               Jido.Domain.Examples.ProvingGround.Routes.CompileWorkspace
             ])

    assert snapshot.manifest_id == "manifest_domain"
    assert snapshot.routes["compile_workspace"].request_type == :command
    assert snapshot.routes["compile_workspace"].semantic_metadata.category == :workspace
  end
end
