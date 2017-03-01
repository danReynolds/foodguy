defmodule Foodguy.RecommendationController do
  @moduledoc """
  Provides recommendations for places to eat based on cuisine and location

  ## Examples
  "I want food in Waterloo, ON"
  "Random sushi in Waterloo, ON"
  "2 pizza places in Waterloo, ON"

  """
  use Foodguy.Web, :controller

  @best_order "best"
  @random_order "random"
  @order %{best: @best_order, random: @random_order}

  @doc """
  Recommendation entrypoint. Begins recommendation query based on request parameters
  and returns the recommendations in JSON
  """
  def recommendation(conn, params) do
    %{
      "city" => city,
      "country" => country,
      "state" => state,
      "cuisines" => cuisines,
      "list_size" => list_size,
      "order" => order
    } = params["result"]["parameters"]
    list_size = String.to_integer(list_size)

    if city == "" do
      json conn, %{speech: "In what city and state or country will you be eating?"}
    else
      case find_city(city, country, state) do
        {:ok, city} ->
          case find_restaurants(city, cuisines) do
            {:ok, restaurants} ->
              json conn, format_restaurants(restaurants, list_size, order)
            {:error, reason} ->
              json conn, %{speech: reason}
          end
        {:error, reason} ->
          json conn, %{speech: reason}
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

  @doc """
  Talks to Zomato to fetch possible city matches for the city query. If successful,
  calls the matching function
  """
  defp find_city(city, country, state) do
    res = HTTPoison.get(
      URI.encode("https://developers.zomato.com/api/v2.1/cities?q=#{city}"),
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

  @doc """
  Fetches restaurants based on provided cuisines for a given city and returns the restaurants
  """
  defp find_restaurants(city, cuisines) do
    case get_cuisines(city, cuisines) do
      {:ok, cuisine_ids} ->
        res = HTTPoison.get(
          URI.encode("https://developers.zomato.com/api/v2.1/search?entity_type=city&entity_id=#{city["id"]}&cuisines=#{Enum.join(cuisine_ids, ",")}&sort=rating"),
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

  @doc """
  Fetches all cuisines for the given city and gets the ids of the ones that match
  the cuisines the user is looking for
  """
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

  @doc """
  Matches the cities returned from Zamato against the arguments provided by the user.
  If there is only 1, instantly matches, 0 returns error, multiple filters by provided
  location and returns the remaining first (typically best) match
  """
  defp match_city(locations, city, country, state) do
    cond do
      length(locations) == 1 ->
        {:ok, hd(locations)}
      length(locations) == 0 ->
        {:error, "A location could not be found by the name #{city}."}
      true ->
        if country == "" && state == "" do
          {:error, "In which city and state or country?"}
        else
          valid_locations = locations
                            |> Enum.filter(fn location -> valid_state?(location, state) end)
                            |> Enum.filter(fn location -> valid_country?(location, country) end)
          cond do
            length(valid_locations) == 0 ->
              {:error, "I was not able to find #{city}."}
            true ->
              {:ok, hd(valid_locations)}
          end
        end
    end
  end

  @doc """
  Transforms the valid restaurants into a useful representation with pertinent
  information to be consumed by api.ai
  """
  defp format_restaurants(restaurants, list_size, order) do
    if order == @order[:random], do: restaurants = Enum.shuffle(restaurants)

    desired_restaurants = Enum.take(restaurants, list_size)
    formatted_default_restaurants = desired_restaurants
                                    |> Enum.map(fn restaurant -> restaurant["restaurant"]["name"] end)
                                    |> Enum.join(", ")
    formatted_rich_restaurants = for restaurant <- desired_restaurants, do: format_restaurant(restaurant["restaurant"])
    default_response = "I recommend going to #{formatted_default_restaurants}."

    %{
      speech: "I recommend going to #{formatted_default_restaurants}.",
      messages: [%{type: 0, speech: "I have some recommendations!"} | formatted_rich_restaurants]
    }
  end

  @doc """
  Formats an individual restaurant for api.ai cards with price, rating, link and title
  """
  defp format_restaurant(restaurant) do
    price = for _ <- 1..restaurant["price_range"], into: "", do: "$"
    %{
     type: 1,
     title: restaurant["name"],
     subtitle: "Rating: #{restaurant["user_rating"]["aggregate_rating"]}, Price: #{price}",
     imageUrl: restaurant["thumb"],
     buttons: [
       %{
         text: "View Restaurant",
         postback: restaurant["url"]
       }
     ]
    }
  end
end
