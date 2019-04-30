defmodule ApiWeb.CacheController do
  use ApiWeb, :controller

  def user(conn, params) do
    id = params["id"]
    res =
      HTTPoison.get!("#{System.get_env("INTERNAL_API")}/v3/cache/user/#{id}").body
      |> Jason.decode!
    conn
    |> pack(res)
  end

  def guild(conn, params) do
    id = params["id"]
    res =
      HTTPoison.get!("#{System.get_env("INTERNAL_API")}/v3/cache/guild/#{id}").body
      |> Jason.decode!
    conn
    |> pack(res)
  end

  def channels(conn, params) do
    id = params["id"]
    res =
      HTTPoison.get!("#{System.get_env("INTERNAL_API")}/v3/cache/guild/#{id}/channels").body
      |> Jason.decode!
    conn
    |> pack(res)
  end

  def roles(conn, params) do
    id = params["id"]
    res =
      HTTPoison.get!("#{System.get_env("INTERNAL_API")}/v3/cache/guild/#{id}/roles").body
      |> Jason.decode!
    conn
    |> pack(res)
  end
end
