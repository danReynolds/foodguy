defmodule Foodguy.CityControllerTest do
  use Foodguy.ConnCase

  alias Foodguy.City
  @valid_attrs %{country: "some content", external_id: 42, name: "some content", state: "some content"}
  @invalid_attrs %{}

  setup %{conn: conn} do
    {:ok, conn: put_req_header(conn, "accept", "application/json")}
  end

  test "lists all entries on index", %{conn: conn} do
    conn = get conn, city_path(conn, :index)
    assert json_response(conn, 200)["data"] == []
  end

  test "shows chosen resource", %{conn: conn} do
    city = Repo.insert! %City{}
    conn = get conn, city_path(conn, :show, city)
    assert json_response(conn, 200)["data"] == %{"id" => city.id,
      "external_id" => city.external_id,
      "state" => city.state,
      "country" => city.country,
      "name" => city.name}
  end

  test "renders page not found when id is nonexistent", %{conn: conn} do
    assert_error_sent 404, fn ->
      get conn, city_path(conn, :show, -1)
    end
  end

  test "creates and renders resource when data is valid", %{conn: conn} do
    conn = post conn, city_path(conn, :create), city: @valid_attrs
    assert json_response(conn, 201)["data"]["id"]
    assert Repo.get_by(City, @valid_attrs)
  end

  test "does not create resource and renders errors when data is invalid", %{conn: conn} do
    conn = post conn, city_path(conn, :create), city: @invalid_attrs
    assert json_response(conn, 422)["errors"] != %{}
  end

  test "updates and renders chosen resource when data is valid", %{conn: conn} do
    city = Repo.insert! %City{}
    conn = put conn, city_path(conn, :update, city), city: @valid_attrs
    assert json_response(conn, 200)["data"]["id"]
    assert Repo.get_by(City, @valid_attrs)
  end

  test "does not update chosen resource and renders errors when data is invalid", %{conn: conn} do
    city = Repo.insert! %City{}
    conn = put conn, city_path(conn, :update, city), city: @invalid_attrs
    assert json_response(conn, 422)["errors"] != %{}
  end

  test "deletes chosen resource", %{conn: conn} do
    city = Repo.insert! %City{}
    conn = delete conn, city_path(conn, :delete, city)
    assert response(conn, 204)
    refute Repo.get(City, city.id)
  end
end
