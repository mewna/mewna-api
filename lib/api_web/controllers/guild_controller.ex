defmodule ApiWeb.GuildController do
  use ApiWeb, :controller
  import Api.AuthHelper
  alias Api.OAuth
  alias Api.Env

  def user_manages_guild(conn, params) do
    if is_token_valid(conn) do
      user_id = conn |> get_auth_header |> OAuth.get_token_user_id
      managed =
        get_managed_guilds_for_user(user_id)
        |> Enum.filter(fn guild ->
          guild["id"] == params["id"]
        end)
      conn |> pack(%{"manages" => (length(managed) == 1)})
    else
      invalid_auth_header conn
    end
  end


  def get_guild_config(conn, params) do
    id = params["id"]
    if manages(conn, id) do
      res =
        HTTPoison.get!("#{Env.internal_api()}/v3/guild/#{id}/config").body
        |> Jason.decode!
      conn |> pack(res)
    else
      conn |> pack(%{})
    end
  end

  def update_guild_config(conn, params) do
    id = params["id"]
    if manages(conn, id) do
      body =
        params
        |> Map.drop(["id"])
        |> Jason.encode!
      res =
        HTTPoison.post!("#{Env.internal_api()}/v3/guild/#{id}/config", body).body
        |> Jason.decode!
      conn |> pack(res)
    else
      conn |> pack(%{})
    end
  end

  def get_guild_webhooks(conn, params) do
    id = params["id"]
    if manages(conn, id) do
      res =
        HTTPoison.get!("#{Env.internal_api()}/v3/guild/#{id}/webhooks").body
        |> Jason.decode!
      conn |> pack(res)
    else
      conn |> pack([])
    end
  end

  def delete_guild_webhook(conn, params) do
    id = params["id"]
    webhook = params["webhook"]
    if manages(conn, id) do
      res =
        HTTPoison.delete!("#{Env.internal_api()}/v3/guild/#{id}/webhooks/#{webhook}").body
        |> Jason.decode!
      conn |> pack(res)
    else
      conn |> pack(%{})
    end
  end

  def info(conn, params) do
    id = params["id"]
    res =
      HTTPoison.get!("#{Env.internal_api()}/v3/guild/#{id}").body
      |> Jason.decode!
    conn
    |> pack(res)
  end

  def update_server_info(conn, params) do
    id = params["id"]
    if manages(conn, id) do
      res =
        HTTPoison.post!("#{Env.internal_api()}/v3/guild/#{id}", Jason.encode!(params)).body
        |> Jason.decode!
      conn |> pack(res)
    else
      conn |> pack(%{})
    end
  end

  def leaderboard(conn, params) do
    id = params["id"]
    p_after = params["after"]
    p_after =
      if p_after do
        parse = Integer.parse p_after
        case parse do
          {x, _} when is_integer(x) ->
            x
          :error ->
            nil
        end
      else
        nil
      end
    query =
      case p_after do
        nil ->
          ""
        _ ->
          "?after=#{p_after}"
      end
    res =
      HTTPoison.get!("#{Env.internal_api()}/v3/guild/#{id}/leaderboard#{query}").body
      |> Jason.decode!
    conn
    |> pack(res)
  end

  def rewards(conn, params) do
    id = params["id"]
    res =
      HTTPoison.get!("#{Env.internal_api()}/v3/guild/#{id}/rewards").body
      |> Jason.decode!
    conn
    |> pack(res)
  end

  def prefix(conn, params) do
    id = params["id"]
    res =
      HTTPoison.get!("#{Env.internal_api()}/v3/guild/#{id}/prefix").body
      |> Jason.decode!
    conn
    |> pack(res)
  end
end
