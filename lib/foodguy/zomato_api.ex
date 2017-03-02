defmodule Foodguy.ZomatoApi do
  alias Foodguy.City
  alias Foodguy.Repo

  @doc """
  Talks to Zomato to fetch possible city matches for the city query. If successful,
  calls the matching function and creates the city.
  """
  def create_city(city_name, country, state) do
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
    state == "" || location["state_code"] == state || location["state_name"] == state
  end

  @doc """
  Determines if a location is valid by checking its full country name against
  the one provided
  """
  defp valid_country?(location, country) do
    country == "" || location["country_name"] == country
  end
end
