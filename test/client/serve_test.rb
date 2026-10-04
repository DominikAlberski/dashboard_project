require_relative "test_helper"
require "net/http"
require_relative "../../client/serve"

class ServeTest < Minitest::Test
  def teardown
    @server&.stop
  end

  def test_get_renders_the_device_list
    api = FakeApi.new
    api.devices = [{ "name" => "pc", "ip" => "192.168.33.10", "online" => true, "registered" => true }]
    start(api)
    assert_includes get("/").body, "pc"
  end

  def test_post_chats_and_shows_the_reply
    api = FakeApi.new
    api.reply = "the answer"
    start(api)
    body = post("/", "text=hello").body
    assert_equal "hello", api.last_text
    assert_includes body, "the answer"
  end

  def test_post_with_no_text_does_not_chat
    api = FakeApi.new
    start(api)
    post("/", "")
    assert_equal 0, api.chat_calls
  end

  def test_a_status_error_renders_a_page
    api = FakeApi.new
    api.status_error = RuntimeError.new("down")
    start(api)
    assert_includes get("/").body, "(no devices)"
  end

  private

  def start(api)
    @server = Serve.new(api, port: 0)
    @port = @server.port
    @thread = Thread.new { @server.run }
  end

  def get(path)
    Net::HTTP.start("127.0.0.1", @port) { |http| http.get(path) }
  end

  def post(path, body)
    request = Net::HTTP::Post.new(path)
    request["Content-Type"] = "application/x-www-form-urlencoded"
    request.body = body
    Net::HTTP.start("127.0.0.1", @port) { |http| http.request(request) }
  end
end
