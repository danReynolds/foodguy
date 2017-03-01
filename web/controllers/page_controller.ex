defmodule Foodguy.PageController do
  use Foodguy.Web, :controller

  def status(conn, _params) do
    render conn, "status.json"
  end
end
