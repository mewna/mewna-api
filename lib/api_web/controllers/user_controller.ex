defmodule ApiWeb.UserController do
  use ApiWeb, :controller
  import Api.AuthHelper

  defp verify_user(conn, check_id) do
    if is_token_valid(conn) do
      token = get_auth_header conn
      token_id = get_token_user token
      check_id == token_id
    else
      false
    end
  end

  def get_user(conn, params) do
    id = params["id"]
    res =
      HTTPoison.get!("#{System.get_env("INTERNAL_API")}/v3/user/#{id}").body
      |> Jason.decode!
    conn
    |> json(res)
  end

  def update_user(conn, params) do
    id = params["id"]
    if verify_user(conn, id) do
      body =
        params
        |> Map.drop(["id"])
        |> Jason.encode!
      res =
        HTTPoison.post!("#{System.get_env("INTERNAL_API")}/v3/user/#{id}", body).body
      IO.inspect res, pretty: true
      res =
        res
        |> Jason.decode!
      conn |> json(res)
    else
      invalid_auth_header conn
    end
  end
end
