defmodule HexWeb.RouterTest do
  use HexWebTest.Case
  import Plug.Test
  alias HexWeb.Router
  alias HexWeb.User
  alias HexWeb.Package
  alias HexWeb.Release
  alias HexWeb.RegistryBuilder

  setup do
    User.create("other", "other@mail.com", "other")
    { :ok, user } = User.create("eric", "eric@mail.com", "eric")
    { :ok, _ }    = Package.create("postgrex", user, [])
    { :ok, pkg }  = Package.create("decimal", user, [])
    { :ok, _ }    = Release.create(pkg, "0.0.1", [{ "postgrex", "0.0.1" }])
    :ok
  end

  test "fetch registry" do
    { :ok, _ } = RegistryBuilder.start_link
    RegistryBuilder.sync_rebuild

    conn = conn("GET", "/registry.ets.gz")
    conn = Router.call(conn, [])

    assert conn.status in 200..399
  after
    RegistryBuilder.stop
  end

  @tag :integration
  test "integration fetch registry" do
    if HexWeb.Config.s3_bucket do
      HexWeb.Config.store(HexWeb.Store.S3)
    end

    { :ok, _ } = RegistryBuilder.start_link
    RegistryBuilder.sync_rebuild

    port = HexWeb.Config.port
    url = String.to_char_list!("http://localhost:#{port}/registry.ets.gz")
    :inets.start

    assert { :ok, response } = :httpc.request(:head, { url, [] }, [], [])
    assert { { _version, 200, _reason }, _headers, _body } = response
  after
    RegistryBuilder.stop
    HexWeb.Config.store(HexWeb.Store.Local)
  end

  @tag :integration
  test "integration fetch tarball" do
    if HexWeb.Config.s3_bucket do
      HexWeb.Config.store(HexWeb.Store.S3)
    end

    headers = [ { "content-type", "application/octet-stream" },
                { "authorization", "Basic " <> :base64.encode("eric:eric") }]
    body = create_tar([app: :postgrex, version: "0.0.1", requirements: [decimal: "~> 0.0.1"]], [])
    conn = conn("POST", "/api/packages/postgrex/releases", body, headers: headers)
    conn = Router.call(conn, [])
    assert conn.status == 201

    port = HexWeb.Config.port
    url = String.to_char_list!("http://localhost:#{port}/tarballs/postgrex-0.0.1.tar")
    :inets.start

    assert { :ok, response } = :httpc.request(:head, { url, [] }, [], [])
    assert { { _version, 200, _reason }, _headers, _body } = response
  after
    HexWeb.Config.store(HexWeb.Store.Local)
  end

  test "redirect" do
    url      = HexWeb.Config.url
    app_host = HexWeb.Config.app_host
    use_ssl  = HexWeb.Config.use_ssl

    HexWeb.Config.url("https://hex.pm")
    HexWeb.Config.app_host("some-host.com")
    HexWeb.Config.use_ssl(true)

    try do
      conn = conn("GET", "/foobar", [], []).scheme(:http)
      conn = Router.call(conn, [])
      assert conn.status == 301
      assert conn.resp_headers["location"] == "https://hex.pm/foobar"

      conn = conn("GET", "/foobar", [], []).scheme(:https).host("some-host.com")
      conn = Router.call(conn, [])
      assert conn.status == 301
      assert conn.resp_headers["location"] == "https://hex.pm/foobar"
    after
      HexWeb.Config.url(url)
      HexWeb.Config.app_host(app_host)
      HexWeb.Config.use_ssl(use_ssl)
    end
  end

  test "forwarded" do
    headers = [ { "x-forwarded-proto", "https" } ]
    conn = conn("GET", "/foobar", [], headers: headers)
    conn = Router.call(conn, [])
    assert conn.scheme == :https

    headers = [ { "x-forwarded-port", "12345" } ]
    conn = conn("GET", "/foobar", [], headers: headers)
    conn = Router.call(conn, [])
    assert conn.port == 12345
  end
end
