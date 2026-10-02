require "minitest/autorun"
require "stringio"
require "json"
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
                :status_response, :chat_response, :status_delay, :clock
  attr_reader :status_calls, :chat_calls, :last_text, :status_starts

  def initialize
    @status_calls = 0
    @chat_calls = 0
    @status_starts = []
    @reply = "ok"
    @devices = []
  end

  def status
    @status_starts << @clock.monotonic if @clock
    @status_calls += 1
    simulate_delay
    raise @status_error if @status_error
    @status_response || { "devices" => @devices }
  end

  def simulate_delay
    @clock.advance(@status_delay) if @clock && @status_delay
  end

  def chat(text)
    @chat_calls += 1
    @last_text = text
    @gate.pop if @gate
    raise @chat_error if @chat_error
    @chat_response || { "reply" => @reply, "action" => "model" }
  end
end

class FakeClock
  attr_reader :sleeps, :now

  def initialize
    @now = 0.0
    @sleeps = []
  end

  def monotonic
    @now
  end

  def sleep(seconds)
    @sleeps << seconds
    @now += seconds
  end

  def advance(seconds)
    @now += seconds
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

  def build_dashboard(api = FakeApi.new, input = FakeInput.new)
    screen = FakeScreen.new
    [Dashboard.new(api, screen, input), screen, input]
  end

  def refresh(dashboard)
    dashboard.poll_status
    dashboard.tick
  end

  def draw_after_status(dashboard)
    dashboard.poll_status
    dashboard.tick
    dashboard.tick
  end

  def submit_chat(api, dashboard, text, count = 1)
    dashboard.submit(text)
    wait_until { api.chat_calls >= count }
  end

  def release_chat(api, dashboard)
    api.gate << true
    wait_until { dashboard.pending_result? }
  end

  def deliver_chat(api, dashboard, text, count)
    submit_chat(api, dashboard, text, count)
    release_chat(api, dashboard)
    dashboard.tick
  end
end
