defmodule Foodguy.Repo.Migrations.CreateCuisine do
  use Ecto.Migration

  def change do
    create table(:cuisines) do
      add :external_id, :integer
      add :name, :string

      timestamps()
    end

  end
end
