require_relative "test_helper"

class LlmTest < Minitest::Test
  class FakeTransport
    attr_reader :calls

    def initialize(response = nil, error: nil)
      @response = response
      @error = error
      @calls = []
    end

    def post(url, body, timeout, connect_limit)
      @calls << { url: url, body: body, timeout: timeout, connect_limit: connect_limit }
      raise @error if @error
      @response
    end

    def get(url, timeout, connect_limit)
      @calls << { url: url, timeout: timeout, connect_limit: connect_limit }
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

    def post(_url, _body, timeout, _connect_limit)
      @clock.advance([@seconds, timeout].min)
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

  def test_chat_posts_the_config_model_without_stream
    transport = reply_transport('{"message":{"content":"ok"}}')
    llm_for(transport).chat("hi")
    call = transport.calls.first
    data = JSON.parse(call[:body])
    assert_equal "http://192.168.33.34:11434/api/chat", call[:url]
    assert_equal 170, call[:timeout]
    assert_equal 5, call[:connect_limit]
    refute data["stream"]
    assert_equal "qwen3.8-ridge-16k:latest", data["model"]
    assert_equal "hi", data["messages"][0]["content"]
  end

  def test_a_slow_model_gives_a_timeout_reply_before_175_seconds
    clock = FakeClock.new
    result = llm_for(SlowTransport.new(clock, 1000)).chat("hi")
    assert_equal Agent::Llm::TIMEOUT_REPLY, result
    assert_operator clock.now, :<, 175
  end

  def test_reachable_uses_the_tags_endpoint
    transport = FakeTransport.new({ code: 200, body: "{}" })
    assert llm_for(transport).reachable?
    call = transport.calls.first
    assert_equal "http://192.168.33.34:11434/api/tags", call[:url]
    assert_equal 2, call[:timeout]
    assert_equal 2, call[:connect_limit]
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
