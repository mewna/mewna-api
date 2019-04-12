defmodule ApiWeb.ApiController do
  use ApiWeb, :controller

  # Fucking CORS man

  def options(conn, _params) do
    conn |> json(%{})
  end
end
