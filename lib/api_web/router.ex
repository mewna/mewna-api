defmodule ApiWeb.Router do
  use ApiWeb, :router

  pipeline :api do
    plug :accepts, ["mewna"]
    plug CORSPlug
  end

  scope "/api", ApiWeb do
    pipe_through :api

    scope "/oauth" do
      scope "/login" do
        get "/start",  OAuthController, :login_start
        get "/finish", OAuthController, :login_finish
      end
      scope "/addbot" do
        get "/start",  OAuthController, :addbot_start
        get "/finish", OAuthController, :addbot_finish
      end
      scope "/webhooks" do
        get "/start",  OAuthController, :webhook_start
        get "/finish", OAuthController, :webhook_finish
      end
    end

    scope "/auth" do
      get  "/heartbeat", AuthController,  :heartbeat
      post "/logout",    OAuthController, :logout
      get  "/homepage",  UserController, :get_homepage
      scope "/guilds" do
        get "/managed",    AuthController, :get_managed_guilds
        get "/unmanaged",  AuthController, :get_unmanaged_guilds
      end
    end

    scope "/guild/:id" do
      get    "/manages",           GuildController, :user_manages_guild
      get    "/leaderboard",       GuildController, :leaderboard
      get    "/rewards",           GuildController, :rewards
      get    "/prefix",            GuildController, :prefix
      get    "/info",              GuildController, :info
      post   "/info",              GuildController, :update_server_info
      get    "/config",            GuildController, :get_guild_config
      post   "/config",            GuildController, :update_guild_config
      get    "/webhooks",          GuildController, :get_guild_webhooks
      delete "/webhooks/:webhook", GuildController, :delete_guild_webhook
      scope "/levels" do
        scope "/import" do
          post "/mee6", GuildController, :import_mee6_levels
        end
      end
    end

    scope "/user" do
      get  "/:id",      UserController, :get_user
      post "/:id",      UserController, :update_user
    end

    scope "/post" do
      get "/author/:id",  PostController, :get_author
      scope "/:id" do
        post   "/create", PostController, :create
        get    "/:post",  PostController, :get_post
        delete "/:post",  PostController, :delete_post
        put    "/:post",  PostController, :edit_post
        get    "/posts",  PostController, :get_posts
      end
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
