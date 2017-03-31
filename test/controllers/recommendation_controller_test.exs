defmodule Foodguy.CityControllerTest do
  use Foodguy.ConnCase

  alias Foodguy.ZomatoApi
  alias Foodguy.RecommendationController
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

  @tag :unit
  describe "#format_restaurant/1" do
    test "assert returns desired restaurant data" do
      restaurant = %{
        "price_range" => 2,
        "name" => "Vincenzo's",
        "thumb" => "http://test.com",
        "url" => "http://test2.com",
        "user_rating" => %{"aggregate_rating" => "Very good"}
      }

      assert RecommendationController.format_restaurant(restaurant) == %{
       type: 1,
       title: restaurant["name"],
       subtitle: "Rating: #{restaurant["user_rating"]["aggregate_rating"]}, Price: $$",
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

  @tag :unit
  describe "#ask_for_location_response" do
    test "assert prompts user for location" do
      messages = %{
        "location" => "In what city and state or country will you be eating?",
        "facebook_location" => "Specify your city and state or country or share your location."
      }

      with_mock Speech, [
        get_speech: fn(key) -> messages[key] end
      ] do
        assert RecommendationController.ask_for_location_response() == %{
         speech: messages["location"],
         data: %{
            google: %{
              expect_user_response: true # Used to keep mic open when a response is needed
            },
            facebook: %{
              text: messages["facebook_location"],
              quick_replies: [%{content_type: "location"}]
            }
          }
        }
      end
    end
  end

  @tag :unit
  describe "#update_location_params/1" do
    test "assert sets city/state/country and clears lat/lon" do
      api_params = %{
        "result" => %{
          "parameters" => %{
            "test" => 2,
            "lat" => 1,
            "lon" => 2,
            "city" => "Waterloo",
            "country" => "Canada",
            "state" => "Ontario"
          }
        }
      }
      expected_params = %{
        "test" => 2,
        "city" => "Waterloo",
        "country" => "Canada",
        "state" => "Ontario",
        "lat" => "",
        "lon" => ""
      }
      assert expected_params == RecommendationController.update_location_params(api_params)
    end

    test "assert sets lat/lon and clears city/state/country" do
      api_params = %{
        "result" => %{
        "parameters" => %{
            "test" => 2,
            "city" => "Toronto",
            "country" => "Canada",
            "state" => "Ontario",
          }
        },
        "originalRequest" => %{
          "data" => %{
            "postback" => %{
              "data" => %{"lat" => 1, "long" => 2}
            }
          }
        }
      }
      expected_params = %{
        "test" => 2,
        "city" => "",
        "country" => "",
        "state" => "",
        "lat" => 1,
        "lon" => 2
      }
      assert expected_params == RecommendationController.update_location_params(api_params)
    end
  end

  @tag :integration
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
