defmodule Foodguy.RecommendationController do
  use Foodguy.Web, :controller

  def recommendation(conn, params) do
    {
      "city": city,
      "country": country,
      "state": state,
      "cuisines": cuisines
    } = params["result"]["parameters"]

    if city == "" do
      json conn, %{speech: "In what city will you be eating?"}
    else
      res = HTTPoison.get(
        "https://developers.zomato.com/api/v2.1/cities?q=#{city}",
        ["user-key": Application.get_env(:foodguy, :zomato)[:api_token]]
      )

      case res do
        {:ok, %HTTPoison.Response{status_code: 200, body: body}} ->
          locations = Poison.Parser.parse!(body)["location_suggestions"]
          case match_city(locations, city, country, state) do
            {:ok, city} ->
              find_restaurants(city, cuisines)
            {:error, reason} ->
              json conn, %{speech: reason}
          end
        {:error, %HTTPoison.Error{reason: reason}} ->
          json conn, %{speech: "There was an error looking for #{city}."}
      end
    end

    json conn, options
  end

  defp valid_state?(location, state) do
     state == "" || location["state_code"] == state || location["state_name"] == state
  end

  defp valid_country?(location, country) do
     country == "" || location["country_name"] == country
  end

  defp match_city(locations, city, country, state) do
    cond do
      length(locations) == 1 ->
        {:ok, hd(locations)}
      length(locations) == 0 ->
        {:error, "A location could not be found by the name #{city}."}
    end

    if country == "" && state == "" do
      {:error, "In which state or country?"}
    else
      valid_locations = locations |> Enum.filter(valid_state?) |> Enum.filter(valid_country?)
      cond do
        length(valid_locations) == 1 ->
          hd(valid_locations)
        country == "" ->
          {:error, "In which country?"}
        state == "" ->
          {:error, "In which state?"}
      end
    end
  end
end
