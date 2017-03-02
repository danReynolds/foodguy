defmodule Foodguy.CuisineController do
  use Foodguy.Web, :controller

  alias Foodguy.Cuisine

  def index(conn, _params) do
    cuisines = Repo.all(Cuisine)
    render(conn, "index.json", cuisines: cuisines)
  end

  def create(conn, %{"cuisine" => cuisine_params}) do
    changeset = Cuisine.changeset(%Cuisine{}, cuisine_params)

    case Repo.insert(changeset) do
      {:ok, cuisine} ->
        conn
        |> put_status(:created)
        |> put_resp_header("location", cuisine_path(conn, :show, cuisine))
        |> render("show.json", cuisine: cuisine)
      {:error, changeset} ->
        conn
        |> put_status(:unprocessable_entity)
        |> render(Foodguy.ChangesetView, "error.json", changeset: changeset)
    end
  end

  def show(conn, %{"id" => id}) do
    cuisine = Repo.get!(Cuisine, id)
    render(conn, "show.json", cuisine: cuisine)
  end

  def update(conn, %{"id" => id, "cuisine" => cuisine_params}) do
    cuisine = Repo.get!(Cuisine, id)
    changeset = Cuisine.changeset(cuisine, cuisine_params)

    case Repo.update(changeset) do
      {:ok, cuisine} ->
        render(conn, "show.json", cuisine: cuisine)
      {:error, changeset} ->
        conn
        |> put_status(:unprocessable_entity)
        |> render(Foodguy.ChangesetView, "error.json", changeset: changeset)
    end
  end

  def delete(conn, %{"id" => id}) do
    cuisine = Repo.get!(Cuisine, id)

    # Here we use delete! (with a bang) because we expect
    # it to always work (and if it does not, it will raise).
    Repo.delete!(cuisine)

    send_resp(conn, :no_content, "")
  end
end
