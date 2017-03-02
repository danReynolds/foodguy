defmodule Foodguy.CuisineControllerTest do
  use Foodguy.ConnCase

  alias Foodguy.Cuisine
  @valid_attrs %{external_id: 42, name: "some content"}
  @invalid_attrs %{}

  setup %{conn: conn} do
    {:ok, conn: put_req_header(conn, "accept", "application/json")}
  end

  test "lists all entries on index", %{conn: conn} do
    conn = get conn, cuisine_path(conn, :index)
    assert json_response(conn, 200)["data"] == []
  end

  test "shows chosen resource", %{conn: conn} do
    cuisine = Repo.insert! %Cuisine{}
    conn = get conn, cuisine_path(conn, :show, cuisine)
    assert json_response(conn, 200)["data"] == %{"id" => cuisine.id,
      "external_id" => cuisine.external_id,
      "name" => cuisine.name}
  end

  test "renders page not found when id is nonexistent", %{conn: conn} do
    assert_error_sent 404, fn ->
      get conn, cuisine_path(conn, :show, -1)
    end
  end

  test "creates and renders resource when data is valid", %{conn: conn} do
    conn = post conn, cuisine_path(conn, :create), cuisine: @valid_attrs
    assert json_response(conn, 201)["data"]["id"]
    assert Repo.get_by(Cuisine, @valid_attrs)
  end

  test "does not create resource and renders errors when data is invalid", %{conn: conn} do
    conn = post conn, cuisine_path(conn, :create), cuisine: @invalid_attrs
    assert json_response(conn, 422)["errors"] != %{}
  end

  test "updates and renders chosen resource when data is valid", %{conn: conn} do
    cuisine = Repo.insert! %Cuisine{}
    conn = put conn, cuisine_path(conn, :update, cuisine), cuisine: @valid_attrs
    assert json_response(conn, 200)["data"]["id"]
    assert Repo.get_by(Cuisine, @valid_attrs)
  end

  test "does not update chosen resource and renders errors when data is invalid", %{conn: conn} do
    cuisine = Repo.insert! %Cuisine{}
    conn = put conn, cuisine_path(conn, :update, cuisine), cuisine: @invalid_attrs
    assert json_response(conn, 422)["errors"] != %{}
  end

  test "deletes chosen resource", %{conn: conn} do
    cuisine = Repo.insert! %Cuisine{}
    conn = delete conn, cuisine_path(conn, :delete, cuisine)
    assert response(conn, 204)
    refute Repo.get(Cuisine, cuisine.id)
  end
end
