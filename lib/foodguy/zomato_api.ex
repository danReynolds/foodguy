defmodule Foodguy.ZomatoApi do
  alias Foodguy.City
  alias Foodguy.Cuisine
  alias Foodguy.Repo
  import Ecto.Query, only: [from: 2]

  @sorting %{
    cheapest: %{type: "cost", order: "asc"},
    priciest: %{type: "cost", order: "desc"},
    best: %{type: "rating", order: "desc"},
    worst: %{type: "rating", order: "asc"},
    random: %{type: "", order: ""},
    nearby: %{type: "", order: ""}
  }

  @doc """
  Fetch restaurants for the specified city and cuisines.
  """
  def fetch_restaurants(url, sorting, cuisine_ids) do
    sort = @sorting[String.to_atom(sorting)]

    res = HTTPoison.get(
      URI.encode("#{url}&sort=#{sort[:type]}&order=#{sort[:order]}&cuisines=#{cuisine_ids}"),
      ["user-key": Application.get_env(:foodguy, :zomato)[:api_token]]
    )
    case res do
      {:ok, %HTTPoison.Response{status_code: 200, body: body}} ->
        restaurants = Poison.Parser.parse!(body)["restaurants"]
        if sorting == "random", do: restaurants = Enum.shuffle(restaurants)
        {:ok, restaurants}
      {:error, %HTTPoison.Error{reason: reason}} ->
        {:error, "There was an error looking for restaurants."}
    end
  end

  @doc """
  Fetch possible city matches for the city query latitude and longitude. If
  successful takes the only result and creates the city if needed.
  """
  def fetch_restaurants_by_city(city, cuisine_ids, sorting) do
    fetch_restaurants("https://developers.zomato.com/api/v2.1/search?entity_type=city&entity_id=#{city.external_id}", sorting, cuisine_ids)
  end

  @doc """
  Fetch possible city matches for the city query latitude and longitude. If
  successful takes the only result and creates the city if needed.
  """
  def fetch_restaurants_by_location(lat, lon, cuisine_ids, sorting) do
    fetch_restaurants("https://developers.zomato.com/api/v2.1/search?lat=#{lat}&lon=#{lon}", sorting, cuisine_ids)
  end

  @doc """
  Fetch possible city matches for the city query. If successful,
  calls the matching function and creates matched the city.
  """
  defp fetch_city(city_name, country, state) do
    res = HTTPoison.get(
      URI.encode("https://developers.zomato.com/api/v2.1/cities?q=#{city_name}"),
      ["user-key": Application.get_env(:foodguy, :zomato)[:api_token]]
    )

    case res do
      {:ok, %HTTPoison.Response{status_code: 200, body: body}} ->
        locations = Poison.Parser.parse!(body)["location_suggestions"]
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
        end
      {:error, %HTTPoison.Error{reason: _reason}} ->
        {:error, "There was an error looking for #{city_name}."}
    end
  end

  @doc """
  Fetches all cuisines for the given city and gets the ids of the ones that match
  the cuisines the user is looking for. Create any ones that are not found.
  """
  def fetch_cuisines(url, cuisine_names) do
    cuisine_query = from cuisine in "cuisines",
                    where: cuisine.name in ^cuisine_names,
                    select: {cuisine.name, cuisine.external_id}
    existing_cuisine_fields = Repo.all(cuisine_query)
    new_cuisine_names = MapSet.to_list(
      MapSet.difference(MapSet.new(cuisine_names),
      MapSet.new(Enum.map(existing_cuisine_fields, fn fields -> elem(fields, 0) end)))
    )

    if length(existing_cuisine_fields) == length(cuisine_names) do
      {:ok, existing_cuisine_fields}
    else
      res = HTTPoison.get(url, ["user-key": Application.get_env(:foodguy, :zomato)[:api_token]])

      case res do
        {:ok, %HTTPoison.Response{status_code: 200, body: body}} ->
          all_cuisines = Poison.Parser.parse!(body)["cuisines"]
          new_cuisines = for cuisine <- all_cuisines,
                                        Enum.member?(new_cuisine_names, cuisine["cuisine"]["cuisine_name"]),
                                        do: elem(Repo.insert(%Cuisine{
                                          name: cuisine["cuisine"]["cuisine_name"],
                                          external_id: cuisine["cuisine"]["cuisine_id"]
                                        }), 1)

          new_cuisine_fields = Enum.map(new_cuisines, fn cuisine -> {cuisine.name, cuisine.external_id} end)
          {:ok, existing_cuisine_fields ++ new_cuisine_fields}
        {:error, %HTTPoison.Error{reason: reason}} ->
          {:error, "There was an error looking for cuisines."}
      end
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
          {:error, "In which city and state or country?"}
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
