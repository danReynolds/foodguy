defmodule Foodguy.CityView do
  use Foodguy.Web, :view

  def render("index.json", %{cities: cities}) do
    %{data: render_many(cities, Foodguy.CityView, "city.json")}
  end

  def render("show.json", %{city: city}) do
    %{data: render_one(city, Foodguy.CityView, "city.json")}
  end

  def render("city.json", %{city: city}) do
    %{id: city.id,
      external_id: city.external_id,
      state: city.state,
      country: city.country,
      name: city.name}
  end
end
