defmodule Foodguy.Cuisine do
  use Foodguy.Web, :model

  schema "cuisines" do
    field :external_id, :integer
    field :name, :string

    timestamps()
  end

  @doc """
  Builds a changeset based on the `struct` and `params`.
  """
  def changeset(struct, params \\ %{}) do
    struct
    |> cast(params, [:external_id, :name])
    |> validate_required([:external_id, :name])
  end
end
