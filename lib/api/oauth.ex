defmodule Api.OAuth do
  alias Api.Redis

  @bearer_tokens "mewna:web:api:oauth:bearer-tokens"
  @user_cache "mewna:web:api:oauth:user-cache"
  @guild_cache "mewna:web:api:oauth:guild-cache"
  @user_tokens "mewna:web:api:tokens"

  # TODO: Expire and update guild / user cache
  # TODO: Use refresh tokens

  def get_user(token) do
    request(:get, token, "/users/@me")
    |> Jason.decode!
  end

  def get_guilds(token) do
    request(:get, token, "/users/@me/guilds")
    |> Jason.decode!
  end

  defp request(method, token, route) do
    HTTPoison.request!(method, "https://discordapp.com/api/v7#{route}", "", [{"Authorization", "Bearer #{token}"}]).body
  end

  def cache_tokens(tokens, id) do
    Redis.command ["HSET", @bearer_tokens, id, Jason.encode!(tokens)]
  end

  def get_cached_tokens(id) do
    Redis.command(["HGET", @bearer_tokens, id])
    |> Jason.decode!
  end

  def cache_user(user) do
    Redis.command ["HSET", @user_cache, user["id"], Jason.encode!(user)]
    user
  end

  def get_cached_user(id) do
    Redis.command(["HGET", @user_cache, id])
    |> Jason.decode!
  end

  def cache_guilds(guilds, id) do
    Redis.command ["HSET", @guild_cache, id, Jason.encode!(guilds)]
  end

  def get_cached_guilds(id) do
    Redis.command(["HGET", @guild_cache, id])
    |> Jason.decode!
  end

  def logout(token) do
    if token_is_valid(token) do
      user = get_token_user_id token
      Redis.command ["SREM", "#{@user_tokens}:#{user}", token]
    end
  end

  def generate_token(id) do
    encoded_id = Base.encode64(id, padding: false)
    encoded_ts =
      :millisecond
      |> :os.system_time
      |> Integer.to_string
      |> Base.encode64(padding: false)
    encoded_hmac =
      :crypto.hmac(:sha256, System.get_env("SIGNING_KEY"), id)
      |> Base.encode64(padding: false)
    token = "#{encoded_id}.#{encoded_ts}.#{encoded_hmac}"
    Redis.command ["SADD", "#{@user_tokens}:#{id}", token]
    token
  end

  def token_is_valid(token) do
    user = get_token_user_id token
    res = Redis.command ["SISMEMBER", "#{@user_tokens}:#{user}", token]
    res == "1" or res == 1 # TODO: Better check here :^(
  end

  def get_token_user_id(token) do
    try do
      status =
        token
        |> String.split(".")
        |> hd
        |> Base.decode64(padding: false)
      case status do
        {:ok, decoded} ->
          decoded
        :error ->
          nil
      end
    rescue
      _ ->
        # Basically just capturing bad token formats
        nil
    end
  end
end
