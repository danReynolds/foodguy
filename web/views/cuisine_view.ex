defmodule Foodguy.CuisineView do
  use Foodguy.Web, :view

  def render("index.json", %{cuisines: cuisines}) do
    %{data: render_many(cuisines, Foodguy.CuisineView, "cuisine.json")}
  end

  def render("show.json", %{cuisine: cuisine}) do
    %{data: render_one(cuisine, Foodguy.CuisineView, "cuisine.json")}
  end

  def render("cuisine.json", %{cuisine: cuisine}) do
    %{id: cuisine.id,
      external_id: cuisine.external_id,
      name: cuisine.name}
  end
end
