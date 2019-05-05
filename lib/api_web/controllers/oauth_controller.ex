defmodule ApiWeb.OAuthController do
  use ApiWeb, :controller
  alias Api.OAuth
  alias Api.Env

  @scopes "identify guilds email guilds.join connections"

  def scopes, do: @scopes

  defp get_auth_header(conn) do
    conn |> get_req_header("authorization") |> hd
  end

  defp is_token_valid(conn) do
    headers = conn |> get_req_header("authorization")
    case headers do
      [] ->
        false
      [header] ->
        OAuth.token_is_valid header
      _ ->
        false
    end
  end

  def login_start(conn, _params) do
    redirect_url = URI.encode_www_form "#{Env.api_url()}/api/oauth/login/finish"
    scopes = URI.encode_www_form @scopes
    conn
    |> redirect(
        external:
          "https://discordapp.com/oauth2/authorize?response_type=code"
            <> "&client_id=#{Env.client_id()}"
            <> "&redirect_uri=#{redirect_url}"
            <> "&scope=#{scopes}"
            <> "&prompt=none"
      )
  end

  def login_finish(conn, params) do
    if params["error"] do
      conn
      |> html("""
      <script>
      self.close();
      </script>
      """)
    else
      scopes = URI.encode_www_form @scopes
      redirect_url = URI.encode_www_form "#{Env.api_url()}/api/oauth/login/finish"
      data = [
        "client_id=#{Env.client_id()}",
        "client_secret=#{Env.client_secret()}",
        "grant_type=authorization_code",
        "code=#{params["code"]}",
        "redirect_uri=#{redirect_url}",
        "scopes=#{scopes}"
      ]
      res =
        HTTPoison.post!("https://discordapp.com/api/v7/oauth2/token",
          Enum.join(data, "&"),
          [{"Content-Type", "application/x-www-form-urlencoded"}]).body

      res =
        unless is_map res do
          Jason.decode! res
        else
          res
        end

      token = res["access_token"]
      cached_tokens = OAuth.with_expires_at res

      # Fetch and cache the user
      user =
        OAuth.get_user(token)
        |> OAuth.cache_user()
      user_id = user["id"]

      # Cache their OAuth tokens
      cached_tokens
      |> OAuth.cache_tokens(user_id)

      # Fetch and cache their guilds
      OAuth.get_guilds(token)
      |> OAuth.cache_guilds(user_id)

      api_token = OAuth.generate_token user_id

      auth_data =
        %{
          "type" => "login",
          "token" => api_token,
        }

      # TODO: Update accounts

      conn
      |> html("""
      <script>
      window.opener.postMessage(#{Jason.encode!(auth_data)}, "*");
      self.close();
      </script>
      """)
    end
  end

  def addbot_start(conn, params) do
    guild_id = params["guild"]
    redirect_url = URI.encode_www_form "#{Env.api_url()}/api/oauth/addbot/finish"
    conn
    |> redirect(
      external:
        "https://discordapp.com/oauth2/authorize?response_type=code"
          <> "&client_id=#{Env.client_id()}"
          <> "&redirect_uri=#{redirect_url}"
          <> "&scope=bot"
          <> "&permissions=8"
          <> "&guild_id=#{guild_id}"
    )
  end

  def addbot_finish(conn, params) do
    if params["error"] do
      conn
      |> html("""
      <script>
      self.close();
      </script>
      """)
    else
      # It's a hack, but it forces us to wait until it's actually cached
      # TODO: Should the timeout be higher?
      Process.sleep 250

      result =
        %{
          "type" => "addbot",
          "guild" => params["guild_id"],
        }

      conn
      |> html("""
      <script>
      window.opener.postMessage(#{Jason.encode!(result)}, "*");
      self.close();
      </script>
      """)
    end
  end

  def webhook_start(conn, _params) do
    redirect_url = URI.encode_www_form "#{Env.api_url()}/api/oauth/webhooks/finish"
    conn
    |> redirect(
        external:
          "https://discordapp.com/oauth2/authorize?response_type=code"
            <> "&client_id=#{Env.webhook_client_id()}"
            <> "&redirect_uri=#{redirect_url}"
            <> "&scope=webhook.incoming"
      )
  end

  def webhook_finish(conn, params) do
    if params["error"] do
      conn
      |> html("""
      <script>
      self.close();
      </script>
      """)
    else
      redirect_url = URI.encode_www_form "#{Env.api_url()}/api/oauth/webhooks/finish"
      data = [
        "client_id=#{Env.webhook_client_id()}",
        "client_secret=#{Env.webhook_client_secret()}",
        "grant_type=authorization_code",
        "code=#{params["code"]}",
        "redirect_uri=#{redirect_url}",
        "scopes=webhook.incoming"
      ]
      res =
        HTTPoison.post!("https://discordapp.com/api/v7/oauth2/token",
          Enum.join(data, "&"),
          [{"Content-Type", "application/x-www-form-urlencoded"}]).body
      res =
        unless is_map res do
          Jason.decode! res
        else
          res
        end

      webhook = res["webhook"]
      webhook = %{
        "channel" => webhook["channel_id"],
        "guild" => webhook["guild_id"],
        "id" => webhook["id"],
        "secret" => webhook["token"],
      }

      HTTPoison.post!(
        "#{Env.internal_api()}/v3/guild/#{webhook["guild"]}/webhooks/add",
        Jason.encode!(webhook),
        [{"Content-Type", "application/json"}]
      )

      conn
      |> html("""
      <script>
      window.opener.postMessage(#{Jason.encode!(%{"reload" => true})}, "*");
      self.close();
      </script>
      """)
    end
  end

  def logout(conn, _params) do
    if is_token_valid(conn) do
      conn
      |> get_auth_header
      |> OAuth.logout
    end
    conn |> pack(%{})
  end
end
