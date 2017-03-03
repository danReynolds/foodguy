defmodule Foodguy.RecommendationController do
  @moduledoc """
  Provides recommendations for places to eat based on cuisine and location

  ## Examples
  "I want food in Waterloo, ON"
  "Random sushi in Waterloo, ON"
  "2 pizza places in Waterloo, ON"

  """
  use Foodguy.Web, :controller
  alias Foodguy.ZomatoApi
  alias Foodguy.City

  @best_order "best"
  @random_order "random"
  @order %{best: @best_order, random: @random_order}

  @doc """
  Recommendation entrypoint. Begins recommendation query based on request parameters
  and returns the recommendations in JSON
  """
  def recommendation(conn, params) do
    %{
      "city" => city_name,
      "country" => country,
      "state" => state,
      "cuisines" => cuisine_names,
      "list_size" => list_size,
      "order" => order
    } = params["result"]["parameters"]
    list_size = String.to_integer(list_size)

    if city_name == "" do
      json conn, %{speech: "In what city and state or country will you be eating?"}
    else
      if city = Repo.get_by(City, name: city_name, state: state) || Repo.get_by(City, name: city_name, country: country) do
        res = {:ok, city}
      else
        res = ZomatoApi.fetch_city(city_name, country, state)
      end

      case res do
        {:ok, city} ->
          case find_restaurants(city, cuisine_names) do
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
  Fetches restaurants based on provided cuisines for a given city and returns the restaurants
  """
  defp find_restaurants(city, cuisine_names) do
    case ZomatoApi.fetch_cuisines(city, cuisine_names) do
      {:ok, cuisine_fields} ->
        cuisine_ids = cuisine_fields |> Enum.map(fn fields -> elem(fields, 1) end) |> Enum.join(",")
        ZomatoApi.fetch_restaurants(city, cuisine_ids)
      {:error, reason} ->
        {:error, "There was an error looking for cuisines in #{city.name}."}
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
