defmodule ApiWeb.AuthController do
  use ApiWeb, :controller
  alias Api.OAuth
  import Api.AuthHelper

  def heartbeat(conn, _params) do
    if is_token_valid(conn) do
      user_id = conn |> get_auth_header |> OAuth.get_token_user_id
      conn |> pack(OAuth.get_cached_user(user_id))
    else
      invalid_auth_header conn
    end
  end

  def get_managed_guilds(conn, _params) do
    if is_token_valid(conn) do
      user_id = conn |> get_auth_header |> OAuth.get_token_user_id
      guilds = get_managed_guilds_for_user user_id
      conn |> pack(guilds)
    else
      invalid_auth_header conn
    end
  end
end
