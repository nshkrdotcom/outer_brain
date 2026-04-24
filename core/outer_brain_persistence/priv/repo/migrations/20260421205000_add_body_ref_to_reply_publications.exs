defmodule OuterBrain.Persistence.Repo.Migrations.AddBodyRefToReplyPublications do
  use Ecto.Migration

  def change do
    alter table(:reply_publications) do
      add(:body_ref, :map, null: false, default: %{})
    end
  end
end
