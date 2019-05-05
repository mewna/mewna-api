defmodule Api.Env do
  def internal_api,           do: System.get_env "INTERNAL_API"
  def api_url,                do: System.get_env "API_URL"
  def client_id,              do: System.get_env "CLIENT_ID"
  def client_secret,          do: System.get_env "CLIENT_SECRET"
  def webhook_client_id,      do: System.get_env "WEBHOOK_CLIENT_ID"
  def webhook_client_secret,  do: System.get_env "WEBHOOK_CLIENT_SECRET"
  def redis_host,             do: System.get_env "REDIS_HOST"
  def redis_auth,             do: System.get_env "REDIS_AUTH"
  def signing_key,            do: System.get_env "SIGNING_KEY"
end
