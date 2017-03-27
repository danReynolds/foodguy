defmodule Foodguy.ZomatoFetcher do
  alias Foodguy.City
  alias Foodguy.Cuisine
  alias Foodguy.Repo
  alias Foodguy.ZomatoApi
  import Ecto.Query, only: [from: 2]

  @sorting %{
    cheapest: %{type: "cost", order: "asc"},
    priciest: %{type: "cost", order: "desc"},
    best: %{type: "rating", order: "desc"},
    worst: %{type: "rating", order: "asc"},
    random: %{type: "", order: ""},
    nearby: %{type: "", order: ""}
  }

  def fetch_restaurants_by_city(id, sorting, cuisine_ids) do
    sort = @sorting[String.to_atom(sorting)]
    params = %{
      entity_id: id,
      entity_type: :city,
      sort: sort[:type],
      order: sort[:order],
      cuisines: cuisine_ids
    }
    fetch_restaurants(params, sorting)
  end

  @doc """
  Fetch possible city matches for the city query latitude and longitude. If
  successful takes the only result and creates the city if needed.
  """
  def fetch_restaurants_by_location(lat, lon, sorting, cuisine_ids) do
    sort = @sorting[String.to_atom(sorting)]
    params = %{
      lat: lat,
      lon: lon,
      sort: sort[:type],
      order: sort[:order],
      cuisines: cuisine_ids
    }
    fetch_restaurants(params, sorting)
  end

  @doc """
  Fetch restaurants for the specified city and cuisines.
  """
  def fetch_restaurants(params, sorting) do
    case ZomatoApi.get_url(:restaurants, params) do
      {:ok, res} ->
        restaurants = res["restaurants"]
        if sorting == "random", do: restaurants = Enum.shuffle(restaurants)
        {:ok, restaurants}
      {:error} ->
        {:error, "There was a problem fetching the restaurants."}
    end
  end

  @doc """
  Fetch possible city matches for the city query. If successful,
  calls the matching function and creates matched the city.
  """
  def fetch_city(city_name, country, state) do
    case ZomatoApi.get_url(:cities, %{q: city_name}) do
      {:ok, res} ->
        locations = res["location_suggestions"]
        case match_city(locations, city_name, country, state) do
          {:ok, city_params} ->
            changeset = City.changeset(%City{}, %{
                name: city_name,
                state: city_params["state_name"],
                country: city_params["country_name"],
                external_id: city_params["id"]
              }
            )
            case Repo.insert(changeset) do
              {:ok, city} ->
                {:ok, city}
              {:error, _changeset} ->
                {:error, "There was a problem with the data for this city."}
            end
          {:error, reason} ->
            {:error, reason}
          {:error} ->
            {:error}
        end
      {:error} ->
        {:error, "There was an error looking for #{city_name}."}
    end
  end

  def fetch_cuisines_by_city(id, cuisine_names) do
    params = %{city_id: id}
    fetch_cuisines(params, cuisine_names)
  end

  def fetch_cuisines_by_location(lat, lon, cuisine_names) do
    params = %{lat: lat, lon: lon}
    fetch_cuisines(params, cuisine_names)
  end

  @doc """
  Fetches all cuisines for the given city and gets the ids of the ones that match
  the cuisines the user is looking for. Create any ones that are not found.
  """
  defp fetch_cuisines(params, cuisine_names) do
    cuisine_query = from cuisine in "cuisines",
                    where: cuisine.name in ^cuisine_names,
                    select: {cuisine.name, cuisine.external_id}
    existing_cuisine_fields = Repo.all(cuisine_query)
    new_cuisine_names = MapSet.to_list(
      MapSet.difference(MapSet.new(cuisine_names),
      MapSet.new(Enum.map(existing_cuisine_fields, fn fields -> elem(fields, 0) end)))
    )

    if length(existing_cuisine_fields) == length(cuisine_names) do
      res = {:ok, existing_cuisine_fields}
    else
      case ZomatoApi.get_url(:cuisines, params) do
        {:ok, data} ->
          all_cuisines = data["cuisines"]
          new_cuisines = for cuisine <- all_cuisines,
                                        Enum.member?(new_cuisine_names, cuisine["cuisine"]["cuisine_name"]),
                                        do: elem(Repo.insert(%Cuisine{
                                          name: cuisine["cuisine"]["cuisine_name"],
                                          external_id: cuisine["cuisine"]["cuisine_id"]
                                        }), 1)

          all_cuisine_fields = existing_cuisine_fields ++ Enum.map(new_cuisines, fn cuisine -> {cuisine.name, cuisine.external_id} end)
          res = {:ok, all_cuisine_fields}
        {:error} ->
          res = {:error, "There was an error looking for cuisines."}
      end
    end

    case res do
      {:ok, cuisine_fields} ->
        {:ok, cuisine_fields |> Enum.map(fn fields -> elem(fields, 1) end) |> Enum.join(",")}
      {:error, error} ->
        {:error, error}
    end
  end

  @doc """
  Matches the cities returned from Zamato against the arguments provided by the user.
  If there is only 1, instantly matches, 0 returns error, multiple filters by provided
  location and returns the remaining first (typically best) match
  """
  defp match_city(locations, city_name, country, state) do
    cond do
      length(locations) == 1 ->
        {:ok, hd(locations)}
      length(locations) == 0 ->
        {:error, "A location could not be found with name #{city_name}."}
      true ->
        if country == "" && state == "" do
          {:error}
        else
          valid_locations = locations
                            |> Enum.filter(fn location -> valid_state?(location, state) end)
                            |> Enum.filter(fn location -> valid_country?(location, country) end)
          cond do
            length(valid_locations) == 0 ->
              {:error, "I was not able to find #{city_name}."}
            true ->
              {:ok, hd(valid_locations)}
          end
        end
    end
  end

  @doc """
  Determines if a location is valid by checking its state code and full name
  against the one provided
  """
  defp valid_state?(location, state) do
    state == "" || location["state_name"] == state
  end

  @doc """
  Determines if a location is valid by checking its full country name against
  the one provided
  """
  defp valid_country?(location, country) do
    country == "" || location["country_name"] == country
  end
end
