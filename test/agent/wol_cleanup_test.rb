require_relative "test_helper"

class WolCleanupTest < Minitest::Test
  MAC = "AA:BB:CC:DD:EE:01".freeze

  class FailedSocket
    def send(*)
      raise IOError, "no route to host"
    end

    def close
      @closed = true
    end

    def closed?
      @closed == true
    end
  end

  # Each wake call must create its own owned socket.
  class OwnedWol < Agent::Wol
    attr_reader :sockets

    def initialize
      super
      @sockets = []
    end

    private

    def broadcast_socket
      socket = AgentTest::FakeSocket.new
      @sockets << socket
      socket
    end
  end

  class FailedWol < Agent::Wol
    attr_reader :sockets

    def initialize
      super
      @sockets = []
    end

    private

    def broadcast_socket
      socket = FailedSocket.new
      @sockets << socket
      socket
    end
  end

  def test_two_wakes_use_two_closed_sockets
    wol = OwnedWol.new
    wol.wake(MAC)
    wol.wake(MAC)
    assert_equal 2, wol.sockets.size
    assert(wol.sockets.all?(&:closed?))
    assert(wol.sockets.all? { |socket| socket.sent.size == 1 })
  end

  def test_concurrent_wakes_use_separate_sockets
    wol = OwnedWol.new
    threads = Array.new(4) { Thread.new { wol.wake(MAC) } }
    threads.each(&:join)
    assert_equal 4, wol.sockets.size
    assert(wol.sockets.all?(&:closed?))
  end

  def test_closes_an_owned_socket_after_failure
    wol = FailedWol.new
    assert_raises(IOError) { wol.wake(MAC) }
    assert wol.sockets.first.closed?
  end

  def test_leaves_an_injected_socket_open
    socket = AgentTest::FakeSocket.new
    Agent::Wol.new(socket).wake(MAC)
    refute socket.closed?
  end
end
