defmodule ApiWeb.PostController do
  use ApiWeb, :controller
  import Api.AuthHelper
  alias Api.Env

  defp verify_user_or_guild(conn, check_id) do
    if is_token_valid(conn) do
      token = get_auth_header conn
      token_id = get_token_user token
      manages_guild =
        get_managed_guilds_for_user(token_id)
        |> Enum.filter(fn guild ->
          guild["id"] == check_id
        end)
      is_token_user = check_id == token_id
      is_token_user || manages_guild
    else
      false
    end
  end

  def create(conn, params) do
    id = params["id"]
    if verify_user_or_guild(conn, id) do
      body =
        params
        |> Map.drop(["id"])
        |> Jason.encode!
      res =
        HTTPoison.post!("#{Env.internal_api()}/v3/post/#{id}/create", body).body
        |> Jason.decode!
      conn |> pack(res)
    else
      invalid_auth_header conn
    end
  end

  def get_post(conn, params) do
    id = params["id"]
    post = params["post"]
    res =
      HTTPoison.get!("#{Env.internal_api()}/v3/post/#{id}/#{post}").body
      |> Jason.decode!
    conn |> pack(res)
  end

  def get_author(conn, params) do
    id = params["id"]
    res =
      HTTPoison.get!("#{Env.internal_api()}/v3/post/author/#{id}").body
      |> Jason.decode!
    conn |> pack(res)
  end

  def delete_post(conn, params) do
    id = params["id"]
    post = params["post"]
    if verify_user_or_guild(conn, id) do
      res =
        HTTPoison.delete!("#{Env.internal_api()}/v3/post/#{id}/#{post}").body
        |> Jason.decode!
      conn |> pack(res)
    else
      invalid_auth_header conn
    end
  end

  def edit_post(conn, params) do
    id = params["id"]
    post = params["post"]
    if verify_user_or_guild(conn, id) do
      res =
        HTTPoison.get!("#{Env.internal_api()}/v3/post/#{id}/#{post}").body
        |> Jason.decode!
      # Verify that they actually authored this post and thus should be allowed to edit it
      # It's easier to do this here than to pass it off to the backend
      # TODO: "Formally" define the structure of this...
      system = res["system"]
      author =
        cond do
          system ->
            false
          true ->
            token = get_auth_header conn
            token_id = get_token_user token
            res["content"]["text"]["author"] == token_id
        end
      if system or not author do
        invalid_auth_header conn
      else
        body =
          params
          # |> Map.put("id", post)
          |> Map.drop(["id", "post"])
          |> Jason.encode!
        res =
          HTTPoison.put!("#{Env.internal_api()}/v3/post/#{id}/#{post}", body).body
          |> Jason.decode!
        conn |> pack(res)
      end
    else
      invalid_auth_header conn
    end
  end

  def get_posts(conn, params) do
    id = params["id"]
    # TODO: Post offset...?
    res =
      HTTPoison.get!("#{Env.internal_api()}/v3/post/#{id}/posts").body
      |> Jason.decode!
    conn |> pack(res)
  end
end
