require_relative "test_helper"

class ApiTest < Minitest::Test
  def setup
    FakeHttp.reset
  end

  def test_status_uses_open_3_and_read_5
    Api.new("http://agent:4567", FakeHttp).status
    assert_equal 3, FakeHttp.instances.last.open_timeout
    assert_equal 5, FakeHttp.instances.last.read_timeout
  end

  def test_chat_uses_open_3_and_read_180
    Api.new("http://agent:4567", FakeHttp).chat("hi")
    assert_equal 3, FakeHttp.instances.last.open_timeout
    assert_equal 180, FakeHttp.instances.last.read_timeout
  end

  def test_chat_posts_json_text
    Api.new("http://agent:4567", FakeHttp).chat("hi")
    request = FakeHttp.instances.last.sent_request
    assert_equal "POST", request.method
    assert_equal({ "text" => "hi" }, JSON.parse(request.body))
    assert_equal "application/json", request["Content-Type"]
  end

  def test_status_parses_body
    FakeHttp.body = '{"devices":[{"name":"pc"}]}'
    result = Api.new("http://agent:4567", FakeHttp).status
    assert_equal "pc", result["devices"].first["name"]
  end
end
