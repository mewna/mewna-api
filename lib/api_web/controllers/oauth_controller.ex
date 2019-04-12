defmodule ApiWeb.OAuthController do
  use ApiWeb, :controller
  alias Api.OAuth

  @scopes "identify guilds email guilds.join connections"

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
    redirect_url = URI.encode_www_form "#{System.get_env("API_URL")}/api/oauth/login/finish"
    scopes = URI.encode_www_form @scopes
    conn
    |> redirect(
        external:
          "https://discordapp.com/oauth2/authorize?response_type=code" <>
            "&client_id=#{System.get_env("CLIENT_ID")}" <>
            "&redirect_uri=#{redirect_url}" <>
            "&scope=#{scopes}"
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
      redirect_url = URI.encode_www_form "#{System.get_env("API_URL")}/api/oauth/login/finish"
      data = [
        "client_id=#{System.get_env("CLIENT_ID")}",
        "client_secret=#{System.get_env("CLIENT_SECRET")}",
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
      user =
        OAuth.get_user(token)
        |> OAuth.cache_user()

      OAuth.get_guilds(token)
      |> OAuth.cache_guilds(user["id"])

      api_token = OAuth.generate_token user["id"]

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

  def webhook_start(conn, _params) do
    redirect_url = URI.encode_www_form "#{System.get_env("API_URL")}/api/oauth/webhooks/finish"
    conn
    |> redirect(
        external:
          "https://discordapp.com/oauth2/authorize?response_type=code" <>
            "&client_id=#{System.get_env("WEBHOOK_CLIENT_ID")}" <>
            "&redirect_uri=#{redirect_url}" <>
            "&scope=webhook.incoming"
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
      redirect_url = URI.encode_www_form "#{System.get_env("API_URL")}/api/oauth/webhooks/finish"
      data = [
        "client_id=#{System.get_env("WEBHOOK_CLIENT_ID")}",
        "client_secret=#{System.get_env("WEBHOOK_CLIENT_SECRET")}",
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
        System.get_env("INTERNAL_API") <> "/v3/guild/#{webhook["guild"]}/webhooks/add",
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
      conn |> get_auth_header |> OAuth.logout
    end
    conn |> text("")
  end
end
