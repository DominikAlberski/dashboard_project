require_relative "test_helper"
require "net/http"
require "socket"

class ServerHttpTest < Minitest::Test
  def teardown
    @server&.stop
  end

  def test_a_missing_content_length_is_411
    start_server
    assert_includes raw_request("POST /api/chat HTTP/1.1\r\nHost: x\r\n\r\n").lines.first, "411"
  end

  def test_oversized_headers_are_413
    start_server
    assert_includes raw_request(oversized_headers).lines.first, "413"
  end

  def test_oversized_headers_with_a_terminator_are_413
    start_server
    assert_includes raw_request(oversized_headers + "\r\n").lines.first, "413"
  end

  def test_an_oversized_body_is_413
    start_server
    request = "POST /api/chat HTTP/1.1\r\nContent-Length: 20000\r\n\r\n"
    assert_includes raw_request(request).lines.first, "413"
  end

  def test_a_read_deadline_is_408
    start_server(read_timeout: 0.1)
    assert_includes stalled_request("GET /api/status HTTP/1.1\r\n").lines.first, "408"
  end

  def test_reads_fragmented_headers_and_body
    start_server
    assert_includes fragmented(fragments).lines.first, "200"
  end

  def test_reads_a_header_in_many_fragments
    start_server
    assert_includes one_byte_fragments("GET /api/status HTTP/1.1\r\nHost: x\r\n\r\n").lines.first, "200"
  end

  def test_each_response_has_content_length_and_connection_close
    start_server
    response = Net::HTTP.start("127.0.0.1", @port) { |http| http.get("/api/status") }
    assert_equal "close", response["connection"].downcase
    assert_operator response["content-length"].to_i, :>, 0
  end

  private

  def start_server(snapshot: AgentTest::StubSnapshot.new, monitor: AgentTest::StubMonitor.new,
                   chat: AgentTest::StubChat.new, read_timeout: 5)
    config = Agent::Config.new("bind" => "127.0.0.1")
    services = { config: config, snapshot: snapshot, monitor: monitor, chat: chat }
    @server = Agent::Server.new(services, port: 0, read_timeout: read_timeout).start
    @port = @server.port
  end

  def raw_request(text)
    socket = TCPSocket.new("127.0.0.1", @port)
    socket.write(text)
    socket.close_write
    socket.read
  ensure
    socket.close unless socket.closed?
  end

  def stalled_request(text)
    socket = TCPSocket.new("127.0.0.1", @port)
    socket.write(text)
    socket.read
  ensure
    socket.close unless socket.closed?
  end

  def fragmented(parts)
    socket = TCPSocket.new("127.0.0.1", @port)
    parts.each do |part|
      socket.write(part)
      sleep 0.01
    end
    socket.close_write
    socket.read
  ensure
    socket.close unless socket.closed?
  end

  def one_byte_fragments(text)
    socket = TCPSocket.new("127.0.0.1", @port)
    text.each_char do |char|
      socket.write(char)
      sleep 0.001
    end
    socket.close_write
    socket.read
  ensure
    socket.close unless socket.closed?
  end

  def oversized_headers
    header = "X: " + ("a" * 200) + "\r\n"
    "GET /api/status HTTP/1.1\r\nHost: x\r\n" + (header * 50)
  end

  def fragments
    body = '{"text":"hi"}'
    head = "POST /api/chat HTTP/1.1\r\nHost: x\r\nContent-Length: #{body.bytesize}\r\n\r\n"
    [head[0, 10], head[10..], body[0, 5], body[5..]]
  end
end
