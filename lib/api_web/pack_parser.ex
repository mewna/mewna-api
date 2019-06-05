defmodule ApiWeb.PackParser do
  require Logger

  @behaviour Plug.Parsers

  @mime "application/x.vnd.mewna+b"

  def mime, do: @mime

  def init(opts) do
    {:ok, opts}
  end

  def parse(conn, type, subtype, _params, opts) do
    {:ok, state} = opts
    if "#{type}/#{subtype}" == @mime do
      {:ok, body, conn} = Plug.Conn.read_body conn, state
      unpacked =
        case body do
          <<192>> ->
            # If there is no request body, it gets encoded to 0xC0 `nil` by
            # msgpack, and 0xC0 is dec. 192.
            %{}
          _ ->
            Msgpax.unpack! body
        end
      {:ok, unpacked, conn}
    else
      {:next, conn}
    end
  end
end
