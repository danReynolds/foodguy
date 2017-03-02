defmodule Foodguy.City do
  use Foodguy.Web, :model

  schema "cities" do
    field :external_id, :integer
    field :state, :string
    field :country, :string
    field :name, :string

    timestamps()
  end

  @doc """
  Builds a changeset based on the `struct` and `params`.
  """
  def changeset(struct, params \\ %{}) do
    struct
    |> cast(params, [:external_id, :state, :country, :name])
    |> validate_required([:external_id, :state, :country, :name])
  end
end
