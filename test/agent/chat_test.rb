require_relative "test_helper"

class ChatTest < Minitest::Test
  class FakeScanner
    attr_reader :pings, :port_checks

    def initialize(ping: true, ports: [])
      @ping = ping
      @ports = ports
      @pings = []
      @port_checks = []
    end

    def ping(ip)
      @pings << ip
      @ping
    end

    def check_ports(ip)
      @port_checks << ip
      @ports
    end
  end

  class FakeSnapshot
    attr_reader :scans

    def initialize
      @scans = 0
    end

    def scan_now
      @scans += 1
      { devices: [] }
    end
  end

  class FakeWol
    attr_reader :macs

    def initialize
      @macs = []
    end

    def wake(mac)
      @macs << mac
    end
  end

  def setup
    @scanner = FakeScanner.new(ports: [80, 443])
    @snapshot = FakeSnapshot.new
    @wol = FakeWol.new
    @llm = AgentTest::FakeLlm.new
  end

  def test_ping_runs_the_scanner
    result = chat.perform("ping", "pc")
    assert_equal ["192.168.33.10"], @scanner.pings
    assert_match "up", result
  end

  def test_scan_runs_a_scan
    assert_equal "scan complete", chat.perform("scan", nil)
    assert_equal 1, @snapshot.scans
  end

  def test_wake_sends_the_registry_mac
    assert_match "pc", chat.perform("wake", "pc")
    assert_equal ["AA:BB:CC:DD:EE:01"], @wol.macs
  end

  def test_ports_lists_the_open_ports
    result = chat.perform("ports", "pc")
    assert_match "80, 443", result
    assert_equal ["192.168.33.10"], @scanner.port_checks
  end

  def test_a_command_is_case_insensitive_with_white_space
    assert_equal "ping", chat.reply("  PING   pc ")[:action]
  end

  def test_an_address_in_the_scan_range_is_a_target
    chat.reply("ping 192.168.33.50")
    assert_equal ["192.168.33.50"], @scanner.pings
  end

  def test_an_address_outside_the_scan_range_is_unknown
    result = chat.reply("ping 10.0.0.5")
    assert_equal "unknown_target", result[:action]
    assert_empty @llm.messages
  end

  def test_an_unknown_target_names_the_registry_devices
    result = chat.reply("ping nope")
    assert_equal "unknown_target", result[:action]
    assert_match "pc", result[:reply]
    assert_match "nas", result[:reply]
    assert_empty @llm.messages
  end

  def test_the_four_commands_do_not_call_the_model
    chat.reply("ping pc")
    chat.reply("scan")
    chat.reply("wake pc")
    chat.reply("ports pc")
    assert_empty @llm.messages
  end

  def test_free_text_goes_to_the_model
    result = chat.reply("tell me a joke")
    assert_equal "model", result[:action]
    assert_equal ["tell me a joke"], @llm.messages
  end

  def test_a_model_timeout_keeps_the_model_action
    @llm = AgentTest::FakeLlm.new(reply: Agent::Llm::TIMEOUT_REPLY)
    result = chat.reply("hello")
    assert_equal "model", result[:action]
    assert_equal Agent::Llm::TIMEOUT_REPLY, result[:reply]
  end

  def test_an_invalid_action_raises
    assert_raises(Agent::Chat::Error) { chat.perform("bad", nil) }
  end

  def test_wake_requires_a_registry_name
    assert_raises(Agent::Chat::Error) { chat.perform("wake", "192.168.33.50") }
  end

  private

  def chat
    Agent::Chat.new({ config: Agent::Config.new, registry: AgentTest.device_registry,
                      scanner: @scanner, snapshot: @snapshot, wol: @wol, llm: @llm })
  end
end
