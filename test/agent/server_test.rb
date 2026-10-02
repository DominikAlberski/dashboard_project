require_relative "test_helper"
require "net/http"

class ServerTest < Minitest::Test
  def teardown
    @server&.stop
  end

  def test_status_returns_the_contract
    devices = [{ name: "pc", ip: "192.168.33.10", mac: nil, online: true, registered: true }]
    start_server(snapshot: AgentTest::StubSnapshot.new(devices: devices), monitor: AgentTest::StubMonitor.new(true))
    response = get("/api/status")
    body = JSON.parse(response.body)
    assert_equal "200", response.code
    assert_equal 1, body["devices"].size
    assert_equal true, body["model"]["reachable"]
    assert body["agent"].key?("started_at")
  end

  def test_unknown_path_is_404
    start_server
    assert_equal 404, get("/api/nope").code.to_i
  end

  def test_a_known_path_with_the_wrong_method_is_405
    start_server
    assert_equal 405, get("/api/chat").code.to_i
    assert_equal 405, post("/api/status", "{}").code.to_i
  end

  def test_a_bad_json_body_is_400
    start_server
    assert_equal 400, post("/api/chat", "{not json").code.to_i
    assert_equal 400, post("/api/chat", "[1, 2]").code.to_i
  end

  def test_a_bad_field_is_422
    start_server
    assert_equal 422, post("/api/chat", "{}").code.to_i
    assert_equal 422, post("/api/action", '{"action":"nope"}').code.to_i
  end

  def test_chat_and_action_payloads
    start_server
    chat = JSON.parse(post("/api/chat", '{"text":"hi"}').body)
    assert_equal "ok", chat["reply"]
    assert_equal "model", chat["action"]
    action = JSON.parse(post("/api/action", '{"action":"ping","target":"pc"}').body)
    assert_equal "done ping pc", action["result"]
  end

  private

  def start_server(snapshot: AgentTest::StubSnapshot.new, monitor: AgentTest::StubMonitor.new,
                   chat: AgentTest::StubChat.new, read_timeout: 5)
    config = Agent::Config.new("bind" => "127.0.0.1")
    services = { config: config, snapshot: snapshot, monitor: monitor, chat: chat }
    @server = Agent::Server.new(services, port: 0, read_timeout: read_timeout).start
    @port = @server.port
  end

  def get(path)
    Net::HTTP.start("127.0.0.1", @port) { |http| http.get(path) }
  end

  def post(path, body)
    request = Net::HTTP::Post.new(path)
    request["Content-Type"] = "application/json"
    request.body = body
    Net::HTTP.start("127.0.0.1", @port) { |http| http.request(request) }
  end
end
