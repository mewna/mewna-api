defmodule Api.AuthHelper do
  use Bitwise
  import Plug.Conn
  import Phoenix.Controller
  alias Api.OAuth

  @manage_guild 0x00000020

  def get_auth_header(conn) do
    conn |> get_req_header("authorization") |> hd
  end

  def is_token_valid(conn) do
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

  def invalid_auth_header(conn) do
    conn
    |> put_status(401)
    |> json(%{"errors" => ["invalid authorization header"]})
  end

  def get_managed_guilds_for_user(user_id) do
    OAuth.get_cached_guilds(user_id)
    |> Enum.filter(fn guild ->
      (guild["permissions"] &&& @manage_guild) == @manage_guild
    end)
  end

  def manages(conn, guild) do
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

  def get_token_user(token) do
    OAuth.get_token_user_id token
  end
end
