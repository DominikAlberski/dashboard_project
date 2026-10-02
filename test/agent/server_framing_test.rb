require_relative "test_helper"
require "socket"

class ServerFramingTest < Minitest::Test
  def teardown
    @server&.stop
  end

  def test_a_malformed_content_length_is_400
    start_server
    assert_includes raw_request(post_head("13junk", '{"text":"hi"}')).lines.first, "400"
  end

  def test_a_negative_content_length_is_400
    start_server
    assert_includes raw_request(post_head("-5", "")).lines.first, "400"
  end

  def test_a_conflicting_content_length_is_400
    start_server
    request = "POST /api/chat HTTP/1.1\r\nContent-Length: 12\r\nContent-Length: 13\r\n\r\n"
    assert_includes raw_request(request).lines.first, "400"
  end

  def test_a_transfer_encoding_is_400
    start_server
    request = "POST /api/chat HTTP/1.1\r\nTransfer-Encoding: chunked\r\n\r\n"
    assert_includes raw_request(request).lines.first, "400"
  end

  def test_a_request_line_without_a_version_is_400
    start_server
    assert_includes raw_request("GET /api/status\r\n\r\n").lines.first, "400"
  end

  def test_an_unsupported_version_is_400
    start_server
    assert_includes raw_request("GET /api/status HTTP/2.0\r\n\r\n").lines.first, "400"
  end

  def test_a_malformed_request_line_is_400
    start_server
    assert_includes raw_request("GET\r\n\r\n").lines.first, "400"
  end

  private

  def start_server
    config = Agent::Config.new("bind" => "127.0.0.1")
    services = { config: config, snapshot: AgentTest::StubSnapshot.new,
                 monitor: AgentTest::StubMonitor.new, chat: AgentTest::StubChat.new }
    @server = Agent::Server.new(services, port: 0).start
    @port = @server.port
  end

  def post_head(value, body)
    "POST /api/chat HTTP/1.1\r\nContent-Length: #{value}\r\n\r\n" + body
  end

  def raw_request(text)
    socket = TCPSocket.new("127.0.0.1", @port)
    socket.write(text)
    socket.close_write
    socket.read
  ensure
    socket.close unless socket.closed?
  end
end
