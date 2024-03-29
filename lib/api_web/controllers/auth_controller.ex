defmodule ApiWeb.AuthController do
  use ApiWeb, :controller
  import Api.AuthHelper
  alias Api.OAuth
  alias Api.Env

  def heartbeat(conn, _params) do
    if is_token_valid(conn) do
      user_id = conn |> get_auth_header |> OAuth.get_token_user_id
      user = OAuth.get_cached_user user_id
      conn |> pack(%{
        "avatar" => user["avatar"],
        "discriminator" => user["discriminator"],
        "id" => user["id"],
        "locale" => user["locale"],
        "username" => user["username"],
      })
    else
      invalid_auth_header conn
    end
  end

  def get_managed_guilds(conn, _params) do
    if is_token_valid(conn) do
      user_id = conn |> get_auth_header |> OAuth.get_token_user_id
      guilds =
        user_id
        |> get_managed_guilds_for_user
        |> Enum.map(fn guild ->
          exists =
            HTTPoison.get!("#{Env.internal_api()}/v3/cache/guild/#{guild["id"]}/exists").body
            |> Jason.decode!
            |> Map.get("exists", false)
          guild
          |> Map.put("exists", exists)
        end)
      conn |> pack(guilds)
    else
      invalid_auth_header conn
    end
  end

  def get_unmanaged_guilds(conn, _params) do
    if is_token_valid(conn) do
      user_id = conn |> get_auth_header |> OAuth.get_token_user_id
      guilds =
        user_id
        |> get_unmanaged_guilds_for_user
        |> Enum.map(fn guild ->
          exists =
            HTTPoison.get!("#{Env.internal_api()}/v3/cache/guild/#{guild["id"]}/exists").body
            |> Jason.decode!
            |> Map.get("exists", false)
          guild
          |> Map.put("exists", exists)
        end)
      conn |> pack(guilds)
    else
      invalid_auth_header conn
    end
  end
end
