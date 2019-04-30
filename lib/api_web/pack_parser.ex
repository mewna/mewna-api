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
      unpacked = Msgpax.unpack! body
      {:ok, unpacked, conn}
    else
      {:next, conn}
    end
  end
end
