defmodule ApiWeb.Router do
  use ApiWeb, :router

  pipeline :api do
    plug :accepts, ["json"]
    plug CORSPlug
  end

  scope "/api", ApiWeb do
    pipe_through :api

    scope "/oauth" do
      scope "/login" do
        get "/start",  OAuthController, :login_start
        get "/finish", OAuthController, :login_finish
      end
      scope "/webhooks" do
        get "/start",  OAuthController, :webhook_start
        get "/finish", OAuthController, :webhook_finish
      end
    end

    scope "/auth" do
      get  "/heartbeat", AuthController,  :heartbeat
      post "/logout",    OAuthController, :logout
      scope "/guilds" do
        get    "/managed",               AuthController, :get_managed_guilds
        get    "/manages/:id",           AuthController, :user_manages_guild
        get    "/config/:id",            AuthController, :get_guild_config
        post   "/config/:id",            AuthController, :update_guild_config
        get    "/webhooks/:id",          AuthController, :get_guild_webhooks
        delete "/webhooks/:id/:webhook", AuthController, :delete_guild_webhook
      end
    end

    scope "/guild/:id" do
      get "/leaderboard", GuildController, :leaderboard
      get "/rewards",     GuildController, :rewards
      get "/prefix",      GuildController, :prefix
    end

    scope "/cache" do
      scope "/user" do
        get "/:id", CacheController, :user
      end
      scope "/guild" do
        get "/:id",          CacheController, :guild
        get "/:id/channels", CacheController, :channels
        get "/:id/roles",    CacheController, :roles
      end
    end

    # tfw CORS is being rude
    # It didn't wanna work without this for some reason tho so bleh
    # Passing an "Authorization" header was triggering a CORS Preflight check
    # This deals with that by giving the right whatevers
    options "/*path", ApiController, :options
  end

  scope "/", ApiWeb do
    options "/*path", ApiController, :options
  end
end
