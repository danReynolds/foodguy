defmodule Foodguy.ZomatoApi do
  @api %{
    restaurants: "https://developers.zomato.com/api/v2.1/search",
    cities: "https://developers.zomato.com/api/v2.1/cities",
    cuisines: "https://developers.zomato.com/api/v2.1/cuisines"
  }

  @doc """
  Makes api calls to Zomato with provided query params
  """
  def get_url(api_key, params) do
    url_params = params
                 |> Enum.filter_map(fn {_, v} -> v != "" end, fn {k, v} -> "#{k}=#{v}" end)
                 |> Enum.join("&")
    uri = URI.encode("#{@api[api_key]}?#{url_params}")
    res = HTTPoison.get(uri, ["user-key": Application.get_env(:foodguy, :zomato)[:api_token]])

    case res do
      {:ok, %HTTPoison.Response{status_code: 200, body: body}} ->
        {:ok, Poison.Parser.parse!(body)}
      {:error, %HTTPoison.Error{reason: _reason}} ->
        {:error}
    end
  end
end
