defmodule Foodguy.RecommendationController do
  use Foodguy.Web, :controller

  def recommendation(conn, params) do
    %{
      "city" => city,
      "country" => country,
      "state" => state,
      "cuisines" => cuisines
    } = params["result"]["parameters"]

    if city == "" do
      json conn, %{speech: "In what city will you be eating?"}
    else
      case find_city(city, country, state) do
        {:ok, city} ->
          case find_restaurants(city, cuisines) do
            {:ok, restaurants} ->
              formatted_restaurants = restaurants
                                      |> Enum.take(3)
                                      |> Enum.map(fn restaurant -> restaurant["restaurant"]["name"] end)
                                      |> Enum.join(",")
              json conn, %{speech: "Go to #{formatted_restaurants}"}
            {:error, reason} ->
              json conn, %{speech: reason}
          end
        {:error, reason} ->
          json conn, %{speech: reason}
      end
    end
  end

  defp valid_state?(location, state) do
    state == "" || location["state_code"] == state || location["state_name"] == state
  end

  defp valid_country?(location, country) do
    country == "" || location["country_name"] == country
  end

  defp find_city(city, country, state) do
    res = HTTPoison.get(
      "https://developers.zomato.com/api/v2.1/cities?q=#{city}",
      ["user-key": Application.get_env(:foodguy, :zomato)[:api_token]]
    )

    case res do
      {:ok, %HTTPoison.Response{status_code: 200, body: body}} ->
        locations = Poison.Parser.parse!(body)["location_suggestions"]
        match_city(locations, city, country, state)
      {:error, %HTTPoison.Error{reason: reason}} ->
        {:error, %{speech: "There was an error looking for #{city}."}}
    end
  end

  defp find_restaurants(city, cuisines) do
    case get_cuisines(city, cuisines) do
      {:ok, cuisine_ids} ->
        res = HTTPoison.get(
          "https://developers.zomato.com/api/v2.1/search?entity_type=city&entity_id=#{city["id"]}&cuisines=#{Enum.join(cuisine_ids, ",")}&sort=rating",
          ["user-key": Application.get_env(:foodguy, :zomato)[:api_token]]
        )
        case res do
          {:ok, %HTTPoison.Response{status_code: 200, body: body}} ->
            {:ok, Poison.Parser.parse!(body)["restaurants"]}
          {:error, %HTTPoison.Error{reason: reason}} ->
            {:error, "There was an error looking for restaurants."}
        end
      {:error, reason} ->
        {:error, "There was an error looking for cuisines in #{city["name"]}."}
    end
  end

  defp get_cuisines(city, cuisines) do
    res = HTTPoison.get(
      "https://developers.zomato.com/api/v2.1/cuisines?city_id=#{city["id"]}",
      ["user-key": Application.get_env(:foodguy, :zomato)[:api_token]]
    )

    case res do
      {:ok, %HTTPoison.Response{status_code: 200, body: body}} ->
        all_cuisines = Poison.Parser.parse!(body)["cuisines"]
        verified_cuisines = for cuisine <- all_cuisines,
                                Enum.member?(cuisines, cuisine["cuisine"]["cuisine_name"]),
                                do: cuisine["cuisine"]["cuisine_id"]
        {:ok, verified_cuisines}
      {:error, %HTTPoison.Error{reason: reason}} ->
        {:error, "There was an error looking for cuisines."}
    end
  end

  defp match_city(locations, city, country, state) do
    cond do
      length(locations) == 1 ->
        {:ok, hd(locations)}
      length(locations) == 0 ->
        {:error, "A location could not be found by the name #{city}."}
      true ->
        if country == "" && state == "" do
          {:error, "In which state or country?"}
        else
          valid_locations = locations
                            |> Enum.filter(fn location -> valid_state?(location, state) end)
                            |> Enum.filter(fn location -> valid_country?(location, country) end)
          cond do
            length(valid_locations) == 1 ->
              {:ok, hd(valid_locations)}
            country == "" ->
              {:error, "In which country?"}
            state == "" ->
              {:error, "In which state?"}
          end
        end
    end
  end
end
