defmodule Foodguy.CityControllerTest do
  use Foodguy.ConnCase

  alias Foodguy.ZomatoApi
  alias Foodguy.Speech
  import Mock

  def test_data(api, test_responses, action) do
    %{
      body: Enum.find(api, fn(req) -> req["name"] == action end)["body"]["text"],
      test_response: Enum.find(test_responses, fn(response) -> response["name"] == action end)
    }
  end

  setup %{conn: conn} do
    {:ok, unparsed_api} = File.read("api.json")
    {:ok, unparsed_test_responses} = File.read("response.json")
    parsed_api = Poison.Parser.parse!(unparsed_api)["resources"]
    parsed_test_responses = Poison.Parser.parse!(unparsed_test_responses)["tests"]
    conn = conn
           |> put_req_header("accept", "application/json")
           |> put_req_header("content-type", "json")

    {:ok, [conn: conn, api: parsed_api, test_responses: parsed_test_responses]}
  end

  describe "POST recommendation/2" do
    test "assert valid response", %{conn: conn, api: api, test_responses: test_responses} do
      %{body: body, test_response: test_response} = test_data(api, test_responses, "assert valid response")
      with_mocks([{
        ZomatoApi,
        [],
        [get_url: fn(api_key, _params) -> {:ok, test_response["responses"][Atom.to_string(api_key)]} end]
      }, {
        Speech,
        [],
        [get_speech: fn("loading") -> "I am fetching some recommendations..." end]
      },
      {
        HTTPoison,
        [],
        [get: fn(_) -> raise "Web Request made" end]
      }]) do
        conn = post conn, "/recommendation", body
        assert json_response(conn, 200) == test_response["value"]
      end
    end
  end
end
