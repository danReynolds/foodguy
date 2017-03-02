defmodule Foodguy.CuisineTest do
  use Foodguy.ModelCase

  alias Foodguy.Cuisine

  @valid_attrs %{external_id: 42, name: "some content"}
  @invalid_attrs %{}

  test "changeset with valid attributes" do
    changeset = Cuisine.changeset(%Cuisine{}, @valid_attrs)
    assert changeset.valid?
  end

  test "changeset with invalid attributes" do
    changeset = Cuisine.changeset(%Cuisine{}, @invalid_attrs)
    refute changeset.valid?
  end
end
