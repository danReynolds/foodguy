defmodule Foodguy.AssignAction do
  def init(options), do: options

  def call(conn, _options) do
    {:ok, body, conn} = Plug.Conn.read_body(conn, length: 1_000_000)
    parsed_body = Poison.Parser.parse!(body)
    action = parsed_body["result"]["action"]
    %{conn | request_path: "/#{action}", path_info: [action], body_params: parsed_body}
  end
end
