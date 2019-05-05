defmodule Api.OAuth do
  alias Api.Env
  alias Api.Redis
  require Logger

  @bearer_tokens "mewna:web:api:oauth:bearer-tokens"
  @user_cache "mewna:web:api:oauth:user-cache"
  @guild_cache "mewna:web:api:oauth:guild-cache"
  @user_tokens "mewna:web:api:tokens"

  # Refresh every 5 minutes
  @cache_timeout 300
  @api_base "https://discordapp.com/api/v7"

  ########################
  # Discord OAuth tokens #
  ########################

  # TODO: Expire and update guild / user cache
  # TODO: Use refresh tokens

  def get_user(token) do
    user =
      request(:get, token, "/users/@me")
      |> Jason.decode!
      if Map.has_key?(user, "retry_after") do
      Process.sleep user["retry_after"] + 5
      get_user token
    else
      user
    end
  end

  def get_guilds(token) do
    guilds =
      request(:get, token, "/users/@me/guilds")
      |> Jason.decode!
    if is_map(guilds) and Map.has_key?(guilds, "retry_after") do
      Process.sleep guilds["retry_after"] + 5
      get_guilds token
    else
      guilds
    end
  end

  defp request(method, token, route) do
    HTTPoison.request!(method, "#{@api_base}#{route}", "", [{"Authorization", "Bearer #{token}"}]).body
  end

  def cache_tokens(tokens, id) do
    Redis.command ["HSET", @bearer_tokens, id, Jason.encode!(tokens)]
    tokens
  end

  def get_cached_tokens(id) do
    Redis.command(["HGET", @bearer_tokens, id])
    |> Jason.decode!
    |> refresh_tokens(id)
  end

  def refresh_tokens(token_map, id) do
    if token_map["expires_at"] > :os.system_time(:second) do
      # Expiration is in the future
      token_map
    else
      Logger.info "Updating Discord OAuth tokens for user #{id}"
      # Needs to be refreshed
      refresh = token_map["refresh_token"]
      scopes = ApiWeb.OAuthController.scopes()
      redirect_url = URI.encode_www_form "#{Env.api_url()}/api/oauth/login/finish"
      data = [
        "client_id=#{Env.client_id()}",
        "client_secret=#{Env.client_secret()}",
        "grant_type=refresh_token",
        "refresh_token=#{refresh}",
        "redirect_uri=#{redirect_url}",
        "scopes=#{scopes}"
      ]
      res =
        HTTPoison.post!("#{@api_base}/oauth2/token",
          Enum.join(data, "&"),
          [{"Content-Type", "application/x-www-form-urlencoded"}]).body

      res =
        unless is_map res do
          Jason.decode! res
        else
          res
        end
      res = with_expires_at res
      cache_tokens res, id
    end
  end

  def with_expires_at(tokens) do
    # Token "expires" at 1 day before the real expiration time, to give us time to refresh it
    expires_at = :os.system_time(:second) + tokens["expires_in"] - 86400
    tokens
    |> Map.drop(["expires_in"])
    |> Map.put("expires_at", expires_at)
  end

  def cache_user(user) do
    Redis.command ["HSET", @user_cache, user["id"], Jason.encode!(user)]
    Redis.command ["HSET", @user_cache, "#{user["id"]}:expires", :os.system_time(:second) + @cache_timeout]
    user
  end

  def get_cached_user(id) do
    user =
      Redis.command(["HGET", @user_cache, id])
      |> Jason.decode!
    expires =
      Redis.command(["HGET", @user_cache, "#{id}:expires"])
      |> String.to_integer
    if expires < :os.system_time(:second) do
      Logger.info "Updating cached Discord user for user #{id}"
      # Expired, refetch
      id
      |> get_cached_tokens
      |> Map.get("access_token")
      |> get_user
      |> cache_user
    else
      user
    end
  end

  def cache_guilds(guilds, id) do
    Redis.command ["HSET", @guild_cache, id, Jason.encode!(guilds)]
    Redis.command ["HSET", @guild_cache, "#{id}:expires", :os.system_time(:second) + @cache_timeout]
    guilds
  end

  def get_cached_guilds(id) do
    guilds = Redis.command(["HGET", @guild_cache, id])
    expires = Redis.command(["HGET", @guild_cache, "#{id}:expires"]) || "0"
    if guilds == nil or expires < :os.system_time(:second) do
      Logger.info "Updating cached Discord guilds for user #{id}"
      # Expired, refetch
      id
      |> get_cached_tokens
      |> Map.get("access_token")
      |> get_guilds
      |> cache_guilds(id)
    else
      guilds
      |> Jason.decode!
    end
  end

  #####################
  # Mewna auth tokens #
  #####################

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
      :crypto.hmac(:sha256, Env.signing_key(), id)
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
