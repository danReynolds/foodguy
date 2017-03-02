defmodule Foodguy.Repo.Migrations.CreateCity do
  use Ecto.Migration

  def change do
    create table(:cities) do
      add :external_id, :integer
      add :state, :string
      add :country, :string
      add :name, :string

      timestamps()
    end

  end
end
