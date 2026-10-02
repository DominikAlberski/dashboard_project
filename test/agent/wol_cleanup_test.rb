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

  class OwnedWol < Agent::Wol
    attr_reader :fake

    private

    def broadcast_socket
      @fake = AgentTest::FakeSocket.new
    end
  end

  class OwnedFailWol < Agent::Wol
    attr_reader :fake

    private

    def broadcast_socket
      @fake = FailedSocket.new
    end
  end

  def test_closes_an_owned_socket_after_success
    wol = OwnedWol.new
    wol.wake(MAC)
    assert wol.fake.closed?
  end

  def test_closes_an_owned_socket_after_failure
    wol = OwnedFailWol.new
    assert_raises(IOError) { wol.wake(MAC) }
    assert wol.fake.closed?
  end

  def test_leaves_an_injected_socket_open
    socket = AgentTest::FakeSocket.new
    Agent::Wol.new(socket).wake(MAC)
    refute socket.closed?
  end
end
