defmodule Foodguy.PageView do
  use Foodguy.Web, :view

  def render("status.json", params) do
    IO.puts(inspect(params))
    %{success: true}
  end
end
