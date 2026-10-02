require "minitest/autorun"
require "stringio"
require "json"
require_relative "../../client/sanitizer"
require_relative "../../client/api"
require_relative "../../client/screen"
require_relative "../../client/dashboard"

class FakeResponse
  attr_reader :body

  def initialize(body)
    @body = body
  end
end

class FakeHttp
  DEFAULT_BODY = '{"devices":[]}'.freeze

  class << self
    attr_writer :body

    def body
      @body || DEFAULT_BODY
    end

    def instances
      @instances ||= []
    end

    def reset
      @instances = []
      @body = nil
    end
  end

  attr_reader :open_timeout, :read_timeout, :sent_request, :host, :port

  def initialize(host, port)
    @host = host
    @port = port
    self.class.instances << self
  end

  def open_timeout=(value)
    @open_timeout = value
  end

  def read_timeout=(value)
    @read_timeout = value
  end

  def start
    yield(self)
  end

  def request(req)
    @sent_request = req
    FakeResponse.new(self.class.body)
  end
end

class FakeApi
  attr_accessor :reply, :devices, :status_error, :chat_error, :gate,
                :status_response, :chat_response
  attr_reader :status_calls, :chat_calls, :last_text

  def initialize
    @status_calls = 0
    @chat_calls = 0
    @reply = "ok"
    @devices = []
  end

  def status
    @status_calls += 1
    raise @status_error if @status_error
    @status_response || { "devices" => @devices }
  end

  def chat(text)
    @chat_calls += 1
    @last_text = text
    @gate.pop if @gate
    raise @chat_error if @chat_error
    @chat_response || { "reply" => @reply, "action" => "model" }
  end
end

class FakeInput
  attr_reader :restore_count

  def initialize(keys = [])
    @keys = keys
    @restore_count = 0
  end

  def with_raw
    yield
  end

  def read_key(_timeout)
    @keys.shift
  end

  def restore
    @restore_count += 1
  end
end

class RaisingInput < FakeInput
  def read_key(_timeout)
    raise "boom"
  end
end

class FakeScreen
  attr_reader :last_state, :draw_count

  def initialize
    @draw_count = 0
  end

  def draw(state)
    @last_state = state
    @draw_count += 1
  end
end

module TestHelpers
  def wait_until(timeout = 2.0)
    deadline = Time.now + timeout
    sleep(0.005) until yield || Time.now > deadline
    raise "condition not met within #{timeout}s" unless yield
  end

  def state_with(overrides = {})
    { :devices => [], :reply => "", :status => "ready",
      :input => "", :thinking => false }.merge(overrides)
  end
end
