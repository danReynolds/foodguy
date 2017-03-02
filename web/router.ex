defmodule Foodguy.Router do
  use Foodguy.Web, :router

  pipeline :browser do
    plug :accepts, ["html"]
    plug :fetch_session
    plug :fetch_flash
    plug :protect_from_forgery
    plug :put_secure_browser_headers
  end

  pipeline :api do
    plug :accepts, ["json", "html"]
  end

  scope "/", Foodguy do
    pipe_through :api

    post "/", PageController, :status
    post "/recommendation", RecommendationController, :recommendation

    resources "/cities", CityController
  end

  # Other scopes may use custom stacks.
  # scope "/api", Foodguy do
  #   pipe_through :api
  # end
end
