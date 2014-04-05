defmodule HexWeb.Router do
  use Plug.Router
  import Plug.Connection
  import HexWeb.Plug
  alias HexWeb.Plugs
  alias HexWeb.Config

  plug Plugs.Exception
  plug Plugs.Forwarded
  plug Plugs.Redirect, ssl: &Config.use_ssl/0, redirect: [&Config.app_host/0], to: &Config.url/0

  plug :fetch
  plug :accept

  plug Plug.MethodOverride
  plug Plug.Head
  plug Plug.Static, at: "/static", from: :hex_web

  plug :match
  plug :dispatch

  # TODO: favicon

  if Mix.env != :prod do
    get "registry.ets.gz" do
      HexWeb.Config.store.registry(conn)
    end

    get "tarballs/:ball" do
      HexWeb.Config.store.tar(conn, ball)
    end
  end

  get "installs/hex.ez" do
    url = HexWeb.Config.cdn_url <> "/installs/hex.ez"

    conn
    |> cache([], [:public, "max-age": 60*60])
    |> redirect(url)
  end

  forward "/api", to: HexWeb.API.Router

  match _ do
    HexWeb.Web.Router.call(conn, [])
  end

  defp fetch(conn, _opts) do
    fetch_params(conn)
  end

  defp accept(conn, _opts) do
    if accept = conn.req_headers["accept"] do
      types = Enum.map(String.split(accept, ","), &:cowboy_http.content_type/1)

       if Enum.find(types, &match?({ :error, _ }, &1)) do
        raise HexWeb.Plug.BadRequest
      else
        types = Enum.map(types, &{ elem(&1, 0), elem(&1, 1) })
        assign(conn, :accepts, types)
      end
    else
      assign(conn, :accepts, [])
    end
  end
end
