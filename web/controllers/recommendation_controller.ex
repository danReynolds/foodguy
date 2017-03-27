defmodule Foodguy.RecommendationController do
  @moduledoc """
  Provides recommendations for places to eat based on cuisine and location

  ## Examples
  "I want food in Waterloo, ON"
  "Random sushi in Waterloo, ON"
  "2 pizza places in Waterloo, ON"

  """
  use Foodguy.Web, :controller
  alias Foodguy.ZomatoFetcher
  alias Foodguy.City

  @doc """
  Recommendation entrypoint. Begins recommendation query based on request parameters
  and returns the recommendations in JSON
  """
  def recommendation(conn, params) do
    api_params = params["result"]["parameters"]
    if location_params = params["originalRequest"]["data"]["postback"]["data"] do
      %{
        "lat" => lat,
        "long" => lon
      } = location_params
      api_params = Map.merge(
        api_params,
        %{"city" => "", "country" => "", "state" => "", "lat" => lat, "lon" => lon}
      )
    else
      if api_params["city"] != "" || api_params["country"] != "" || api_params["state"] != "" do
        api_params = Map.merge(
          api_params,
          %{"lat" => "", "lon" => ""}
        )
      end
    end

    %{
      "city" => city_name,
      "country" => country,
      "state" => state,
      "cuisines" => cuisine_names,
      "list_size" => list_size,
      "sorting" => sorting,
      "lat" => lat,
      "lon" => lon
    } = api_params
    list_size = String.to_integer(list_size)

    if lat != "" && lon != "" do
      if sorting == "", do: sorting = "nearby"
      case find_restaurants_by_location(lat, lon, cuisine_names, sorting) do
        {:ok, restaurants} ->
          res = format_restaurants(restaurants, list_size)
          res = Map.put(res, :contextOut, [%{
            name: "recommendation",
            lifespan: 5,
            parameters: api_params
          }])
          json conn, res
        {:error, reason} ->
          json conn, %{speech: reason}
      end
    else
      if city_name != "" do
        if city = Repo.get_by(City, name: city_name, state: state) || Repo.get_by(City, name: city_name, country: country) do
          res = {:ok, city}
        else
          res = ZomatoFetcher.fetch_city(city_name, country, state)
        end
      end

      case res do
        {:ok, city} ->
          if sorting == "", do: sorting = "random"
          case find_restaurants_by_city(city, cuisine_names, sorting) do
            {:ok, restaurants} ->
              res = format_restaurants(restaurants, list_size)
              res = Map.put(res, :contextOut, [%{
                name: "recommendation",
                lifespan: 5,
                parameters: api_params
              }])
              json conn, res
            {:error, reason} ->
              json conn, %{speech: reason}
          end
        {:error, reason} ->
          json conn, %{speech: reason}
        nil ->
          json conn, %{
            speech: "In what city and state or country will you be eating?",
            data: %{
              google: %{
                expect_user_response: true # Used to keep mic open when a response is needed
              },
              facebook: %{
                text: "Specify your city and state or country or share your location.",
                quick_replies: [%{
                  content_type: "location"
                }]
              }
            }
          }
      end
    end
  end

  @doc """
  Fetches restaurants based on provided cuisines for a given city and returns the restaurants
  """
  defp find_restaurants_by_city(city, cuisine_names, sorting) do
    case ZomatoFetcher.fetch_cuisines_by_city(city.external_id, cuisine_names) do
      {:ok, cuisine_ids} ->
        IO.puts(inspect(cuisine_ids))
        ZomatoFetcher.fetch_restaurants_by_city(city.external_id, sorting, cuisine_ids)
      {:error, error} ->
        {:error, error}
    end
  end

  @doc """
  Fetches restaurants based on provided cuisines for a given city and returns the restaurants
  """
  defp find_restaurants_by_location(lat, lon, cuisine_names, sorting) do
    case ZomatoFetcher.fetch_cuisines_by_location(lat, lon, cuisine_names) do
      {:ok, cuisine_ids} ->
        IO.puts(inspect(cuisine_ids))
        ZomatoFetcher.fetch_restaurants_by_location(lat, lon, sorting, cuisine_ids)
      {:error, reason} ->
        {:error, "There was an error looking for cuisines in your specified location."}
    end
  end

  @doc """
  Transforms the valid restaurants into a useful representation with pertinent
  information to be consumed by api.ai
  """
  defp format_restaurants(restaurants, list_size) do
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
