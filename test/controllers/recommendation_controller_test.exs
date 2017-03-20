defmodule Foodguy.CityControllerTest do
  use Foodguy.ConnCase

  alias Foodguy.City
  import Mock

  def req_data(api, responses, action) do
    %{
      body: Enum.find(api, fn(req) -> req["name"] == action end)["body"]["text"],
      response: Enum.find(responses, fn(response) -> response["name"] == action end)["body"]
    }
  end

  setup %{conn: conn} do
    {:ok, unparsed_api} = File.read("api.json")
    {:ok, unparsed_responses} = File.read("response.json")
    parsed_api = Poison.Parser.parse!(unparsed_api)["resources"]
    parsed_responses = Poison.Parser.parse!(unparsed_responses)["responses"]
    conn = conn
           |> put_req_header("accept", "application/json")
           |> put_req_header("content-type", "json")

    {:ok, [conn: conn, api: parsed_api, responses: parsed_responses]}
  end

  describe "POST recommendation/2" do
    test "", %{conn: conn, api: api, responses: responses} do
      %{body: body, response: response} = req_data(api, responses, "Recommendation")
      with_mock HTTPoison, [get: fn(_url) -> response end] do
        conn = post conn, "/recommendation", body
      end
      assert json_response(conn, 200)["speech"] =~ response["speech"]
    end
  end
end
