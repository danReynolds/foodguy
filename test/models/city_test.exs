defmodule Foodguy.CityTest do
  use Foodguy.ModelCase

  alias Foodguy.City

  @valid_attrs %{country: "some content", external_id: 42, name: "some content", state: "some content"}
  @invalid_attrs %{}

  test "changeset with valid attributes" do
    changeset = City.changeset(%City{}, @valid_attrs)
    assert changeset.valid?
  end

  test "changeset with invalid attributes" do
    changeset = City.changeset(%City{}, @invalid_attrs)
    refute changeset.valid?
  end
end
