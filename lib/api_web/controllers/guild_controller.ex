defmodule ApiWeb.GuildController do
  use ApiWeb, :controller

  def info(conn, params) do
    id = params["id"]
    res =
      HTTPoison.get!("#{System.get_env("INTERNAL_API")}/v3/guild/#{id}").body
      |> Jason.decode!
    conn
    |> json(res)
  end

  def leaderboard(conn, params) do
    id = params["id"]
    res =
      HTTPoison.get!("#{System.get_env("INTERNAL_API")}/v3/guild/#{id}/leaderboard").body
      |> Jason.decode!
    conn
    |> json(res)
  end

  def rewards(conn, params) do
    id = params["id"]
    res =
      HTTPoison.get!("#{System.get_env("INTERNAL_API")}/v3/guild/#{id}/rewards").body
      |> Jason.decode!
    conn
    |> json(res)
  end

  def prefix(conn, params) do
    id = params["id"]
    res =
      HTTPoison.get!("#{System.get_env("INTERNAL_API")}/v3/guild/#{id}/prefix").body
      |> Jason.decode!
    conn
    |> json(res)
  end
end
