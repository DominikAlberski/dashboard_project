require_relative "test_helper"

class WolTest < Minitest::Test
  MAC = "AA:BB:CC:DD:EE:01".freeze
  MAC_BYTES = [0xAA, 0xBB, 0xCC, 0xDD, 0xEE, 0x01].freeze

  class FailingSocket
    def send(*)
      raise IOError, "no route to host"
    end
  end

  def test_the_packet_has_the_magic_header
    packet = captured_packet
    assert_equal 102, packet.bytesize
    assert_equal [0xFF] * 6, packet.bytes.first(6)
  end

  def test_the_packet_repeats_the_mac_sixteen_times
    packet = captured_packet
    assert_equal MAC_BYTES, packet.bytes[6, 6]
    assert_equal MAC_BYTES * 16, packet.bytes[6, 96]
  end

  def test_wake_sends_over_udp_broadcast
    socket = AgentTest::FakeSocket.new
    Agent::Wol.new(socket).wake("aa-bb-cc-dd-ee-01")
    sent = socket.sent.first
    assert_equal "255.255.255.255", sent[:host]
    assert_equal 9, sent[:port]
  end

  def test_run_succeeds_for_a_mac
    code, = Agent::Wol.run([MAC], registry: registry, socket: AgentTest::FakeSocket.new)
    assert_equal 0, code
  end

  def test_run_resolves_a_registry_name
    socket = AgentTest::FakeSocket.new
    code, = Agent::Wol.run(["pc"], registry: registry, socket: socket)
    assert_equal 0, code
    refute_empty socket.sent
  end

  def test_run_rejects_a_bad_argument
    code, message = Agent::Wol.run([], registry: registry)
    assert_equal 2, code
    assert_match "usage", message
  end

  def test_run_reports_a_send_failure
    code, = Agent::Wol.run([MAC], registry: registry, socket: FailingSocket.new)
    assert_equal 1, code
  end

  private

  def captured_packet
    socket = AgentTest::FakeSocket.new
    Agent::Wol.new(socket).wake(MAC)
    socket.sent.first[:data]
  end

  def registry
    Agent::Registry.new([{ "name" => "pc", "mac" => MAC, "ip" => "192.168.33.10" }])
  end
end
