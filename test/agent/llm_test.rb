require_relative "test_helper"

class LlmTest < Minitest::Test
  class FakeTransport
    attr_reader :calls

    def initialize(response = nil, error: nil)
      @response = response
      @error = error
      @calls = []
    end

    def post(url, body, options)
      @calls << { url: url, body: body, options: options }
      raise @error if @error
      @response
    end

    def get(url, options)
      @calls << { url: url, options: options }
      raise @error if @error
      @response
    end
  end

  class FakeClock
    attr_reader :now

    def initialize
      @now = 0.0
    end

    def advance(seconds)
      @now += seconds
    end
  end

  class SlowTransport
    def initialize(clock, seconds)
      @clock = clock
      @seconds = seconds
    end

    def post(_url, _body, options)
      @clock.advance([@seconds, options[:timeout]].min)
      raise Agent::Transport::Error, "timeout"
    end
  end

  def test_removes_think_blocks
    transport = reply_transport('{"message":{"content":"A<think>secret</think>B"}}')
    assert_equal "AB", llm_for(transport).chat("hi")
  end

  def test_ignores_message_thinking
    transport = reply_transport('{"message":{"content":"hello","thinking":"secret"}}')
    assert_equal "hello", llm_for(transport).chat("hi")
  end

  def test_chat_posts_to_the_config_model
    transport = reply_transport('{"message":{"content":"ok"}}')
    llm_for(transport).chat("hi")
    data = JSON.parse(transport.calls.first[:body])
    assert_equal "http://192.168.33.34:11434/api/chat", transport.calls.first[:url]
    assert_equal "qwen3.8-ridge-16k:latest", data["model"]
    refute data["stream"]
  end

  def test_chat_sends_the_user_text
    transport = reply_transport('{"message":{"content":"ok"}}')
    llm_for(transport).chat("hi")
    data = JSON.parse(transport.calls.first[:body])
    assert_equal "hi", data["messages"][0]["content"]
  end

  def test_chat_uses_the_timeout_budget
    transport = reply_transport('{"message":{"content":"ok"}}')
    llm_for(transport).chat("hi")
    options = transport.calls.first[:options]
    assert_equal 170, options[:timeout]
    assert_equal 5, options[:connect]
  end

  def test_a_slow_model_gives_a_timeout_reply_before_175_seconds
    clock = FakeClock.new
    result = llm_for(SlowTransport.new(clock, 1000)).chat("hi")
    assert_equal Agent::Llm::TIMEOUT_REPLY, result
    assert_operator clock.now, :<=, 170
  end

  def test_a_non_success_status_is_a_model_failure
    transport = FakeTransport.new({ code: 404, body: '{"error":"model missing"}' })
    assert_equal Agent::Llm::TIMEOUT_REPLY, llm_for(transport).chat("hi")
  end

  def test_invalid_json_is_a_model_failure
    transport = FakeTransport.new({ code: 200, body: "not json" })
    assert_equal Agent::Llm::TIMEOUT_REPLY, llm_for(transport).chat("hi")
  end

  def test_a_json_array_is_a_model_failure
    transport = FakeTransport.new({ code: 200, body: "[1, 2]" })
    assert_equal Agent::Llm::TIMEOUT_REPLY, llm_for(transport).chat("hi")
  end

  def test_missing_content_is_a_model_failure
    transport = FakeTransport.new({ code: 200, body: '{"message":{}}' })
    assert_equal Agent::Llm::TIMEOUT_REPLY, llm_for(transport).chat("hi")
  end

  def test_a_trailing_slash_model_host_uses_one_slash
    config = Agent::Config.new("model_host" => "http://host:11434/")
    transport = reply_transport('{"message":{"content":"ok"}}')
    llm = Agent::Llm.new(config, transport)
    llm.chat("hi")
    llm.reachable?
    urls = transport.calls.map { |call| call[:url] }
    assert_includes urls, "http://host:11434/api/chat"
    assert_includes urls, "http://host:11434/api/tags"
  end

  def test_reachable_uses_the_tags_endpoint
    transport = FakeTransport.new({ code: 200, body: "{}" })
    assert llm_for(transport).reachable?
    call = transport.calls.first
    assert_equal "http://192.168.33.34:11434/api/tags", call[:url]
    assert_equal 2, call[:options][:timeout]
    assert_equal 2, call[:options][:connect]
  end

  def test_reachable_is_false_on_a_transport_error
    transport = FakeTransport.new(nil, error: Agent::Transport::Error.new("down"))
    refute llm_for(transport).reachable?
  end

  private

  def reply_transport(json)
    FakeTransport.new({ code: 200, body: json })
  end

  def llm_for(transport)
    Agent::Llm.new(Agent::Config.new, transport)
  end
end
