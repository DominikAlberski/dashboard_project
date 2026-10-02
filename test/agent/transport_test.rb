require_relative "test_helper"

class TransportTest < Minitest::Test
  # The fake HTTP class yields a session whose request blocks for 5 seconds.
  class SlowHttp
    def self.start(*)
      yield new
    end

    def request(*)
      sleep 5
    end
  end

  def test_the_deadline_aborts_a_slow_request
    transport = Agent::Transport.new(SlowHttp)
    started = Time.now
    assert_raises(Agent::Transport::Error) do
      transport.get("http://host/api/tags", timeout: 0.2, connect: 0.2)
    end
    assert_operator Time.now - started, :<, 2
  end
end
