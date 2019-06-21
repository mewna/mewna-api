defmodule ApiWeb.UserController do
  use ApiWeb, :controller
  import Api.AuthHelper
  alias Api.Env
  alias Api.OAuth

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
      HTTPoison.get!("#{Env.internal_api()}/v3/user/#{id}").body
      |> Jason.decode!
    conn
    |> pack(res)
  end

  def update_user(conn, params) do
    id = params["id"]
    if verify_user(conn, id) do
      body =
        params
        |> Map.drop(["id"])
        |> Jason.encode!
      res =
        HTTPoison.post!("#{Env.internal_api()}/v3/user/#{id}", body).body
        |> Jason.decode!
      conn |> pack(res)
    else
      invalid_auth_header conn
    end
  end

  def get_homepage(conn, _params) do
    ids = get_homepage_ids conn
    case ids do
      nil ->
        invalid_auth_header conn
      _ ->
        res =
          HTTPoison.post!("#{Env.internal_api()}/v3/homepage", Jason.encode!(ids)).body
          |> Jason.decode!
        conn |> pack(res)
    end
  end

  defp get_homepage_ids(conn) do
    if is_token_valid(conn) do
      token = get_auth_header conn
      user = get_token_user token
      user
      |> OAuth.get_cached_guilds
      |> Enum.map(fn guild -> guild["id"] end)
    else
      nil
    end
  end

  def get_premium_settings(conn, params) do
    if is_token_valid(conn) do
      token = get_auth_header conn
      id = get_token_user token
      res =
        HTTPoison.get!("#{Env.internal_api()}/v3/user/#{id}/premium").body
        |> Jason.decode!
      conn
      |> pack(res)
    else
      conn
      |> pack(%{})
    end
  end
end
