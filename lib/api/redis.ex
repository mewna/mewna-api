defmodule Api.Redis do
  alias Api.Env

  @pool_size 5

  def child_spec(_args) do
    # Specs for the Redix connections.
    children =
      for i <- 0..(@pool_size - 1) do
        Supervisor.child_spec({Redix, [
            host: Env.redis_host(),
            port: 6379,
            password: Env.redis_auth(),
            name: :"redix_#{i}"
          ]}, id: {Redix, i})
      end

    # Spec for the supervisor that will supervise the Redix connections.
    %{
      id: RedixSupervisor,
      type: :supervisor,
      start: {Supervisor, :start_link, [children, [strategy: :one_for_one]]}
    }
  end

  def command(command) do
    {:ok, data} = Redix.command(:"redix_#{random_index()}", command)
    data
  end

  defp random_index() do
    rem(System.unique_integer([:positive]), @pool_size)
  end
end
