require_relative "test_helper"
require "socket"

class ServerDeadlineTest < Minitest::Test
  def teardown
    @server&.stop
  end

  # Slow headers use part of the timeout. The body must get a fresh deadline.
  def test_headers_and_body_get_separate_deadlines
    start_server(read_timeout: 1.5)
    assert_includes slow_fragmented.lines.first, "200"
  end

  private

  def start_server(read_timeout: 5)
    config = Agent::Config.new("bind" => "127.0.0.1")
    services = { config: config, snapshot: AgentTest::StubSnapshot.new,
                 monitor: AgentTest::StubMonitor.new, chat: AgentTest::StubChat.new }
    @server = Agent::Server.new(services, port: 0, read_timeout: read_timeout).start
    @port = @server.port
  end

  def slow_fragmented
    socket = TCPSocket.new("127.0.0.1", @port)
    write_request(socket)
    socket.close_write
    socket.read
  ensure
    socket.close unless socket.closed?
  end

  def write_request(socket)
    body = '{"text":"hi"}'
    head = "POST /api/chat HTTP/1.1\r\nContent-Length: #{body.bytesize}\r\n\r\n"
    write_part(socket, head[0, 20], 1.0)
    write_part(socket, head[20..], 0.4)
    write_part(socket, body[0, 6], 0.4)
    socket.write(body[6..])
  end

  def write_part(socket, part, pause)
    socket.write(part)
    sleep pause
  end
end
