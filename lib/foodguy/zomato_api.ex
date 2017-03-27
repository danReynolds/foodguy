defmodule Foodguy.ZomatoApi do
  @restaurants_url "https://developers.zomato.com/api/v2.1/search"

  @api %{
    restaurants: "https://developers.zomato.com/api/v2.1/search",
    cities: "https://developers.zomato.com/api/v2.1/cities",
    cuisines: "https://developers.zomato.com/api/v2.1/cuisines"
  }

  def get_url(url, params) do
    url_params = params
                 |> Enum.filter_map(fn {k, v} -> v != "" end, fn {k, v} -> "#{k}=#{v}" end)
                 |> Enum.join("&")
    uri = URI.encode("#{@api[url]}?#{url_params}")
    res = HTTPoison.get(uri, ["user-key": Application.get_env(:foodguy, :zomato)[:api_token]])

    case res do
      {:ok, %HTTPoison.Response{status_code: 200, body: body}} ->
        {:ok, Poison.Parser.parse!(body)}
      {:error, %HTTPoison.Error{reason: reason}} ->
        {:error}
    end
  end
end
