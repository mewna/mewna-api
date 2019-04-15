defmodule ApiWeb.AuthController do
  use ApiWeb, :controller
  use Bitwise
  alias Api.OAuth

  @manage_guild 0x00000020

  defp get_auth_header(conn) do
    conn |> get_req_header("authorization") |> hd
  end

  defp is_token_valid(conn) do
    headers = conn |> get_req_header("authorization")
    case headers do
      [] ->
        false
      [header] ->
        OAuth.token_is_valid(header)
      _ ->
        false
    end
  end

  defp invalid_auth_header(conn) do
    conn
    |> put_status(401)
    |> json(%{"errors" => ["invalid authorization header"]})
  end

  defp get_managed_guilds_for_user(user_id) do
    OAuth.get_cached_guilds(user_id)
    |> Enum.filter(fn guild ->
      (guild["permissions"] &&& @manage_guild) == @manage_guild
    end)
  end

  defp manages(conn, guild) do
    if is_token_valid(conn) do
      user_id = conn |> get_auth_header |> OAuth.get_token_user_id
      manages =
        user_id
        |> get_managed_guilds_for_user
        |> Enum.filter(fn g ->
          g["id"] == guild
        end)
        |> length
      manages == 1
    else
      false
    end
  end

  def heartbeat(conn, _params) do
    if is_token_valid(conn) do
      user_id = conn |> get_auth_header |> OAuth.get_token_user_id
      conn |> json(OAuth.get_cached_user(user_id))
    else
      invalid_auth_header conn
    end
  end

  def get_managed_guilds(conn, _params) do
    if is_token_valid(conn) do
      user_id = conn |> get_auth_header |> OAuth.get_token_user_id
      guilds = get_managed_guilds_for_user user_id
      conn |> json(guilds)
    else
      invalid_auth_header conn
    end
  end

  def user_manages_guild(conn, params) do
    if is_token_valid(conn) do
      user_id = conn |> get_auth_header |> OAuth.get_token_user_id
      managed =
        get_managed_guilds_for_user(user_id)
        |> Enum.filter(fn guild ->
          guild["id"] == params["id"]
        end)
      conn |> json(%{"manages" => (length(managed) == 1)})
    else
      invalid_auth_header conn
    end
  end

  def get_guild_config(conn, params) do
    id = params["id"]
    if manages(conn, id) do
      res =
        HTTPoison.get!("#{System.get_env("INTERNAL_API")}/v3/guild/#{id}/config").body
        |> Jason.decode!
      conn |> json(res)
    else
      conn |> json(%{})
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
        HTTPoison.post!("#{System.get_env("INTERNAL_API")}/v3/guild/#{id}", body).body
        |> Jason.decode!
      conn |> json(res)
    else
      conn |> json(%{})
    end
  end

  def get_guild_webhooks(conn, params) do
    id = params["id"]
    if manages(conn, id) do
      res =
        HTTPoison.get!("#{System.get_env("INTERNAL_API")}/v3/guild/#{id}/webhooks").body
        |> Jason.decode!
      conn |> json(res)
    else
      conn |> json([])
    end
  end

  def delete_guild_webhook(conn, params) do
    id = params["id"]
    webhook = params["webhook"]
    if manages(conn, id) do
      res =
        HTTPoison.delete!("#{System.get_env("INTERNAL_API")}/v3/guild/#{id}/webhooks/#{webhook}").body
        |> Jason.decode!
      conn |> json(res)
    else
      conn |> json(%{})
    end
  end

  def update_server_info(conn, params) do
    id = params["id"]
    if manages(conn, id) do
      res =
        HTTPoison.post!("#{System.get_env("INTERNAL_API")}/v3/guild/#{id}", Jason.encode!(params)).body
        |> Jason.decode!
      conn |> json(res)
    else
      conn |> json(%{})
    end
  end
end
