require_relative "test_helper"

class ScannerTest < Minitest::Test
  ARP_OUTPUT = <<~ARP
    ? (192.168.33.1) at aa:bb:cc:dd:ee:01 on en0 ifscope [ethernet]
    ? (192.168.33.2) at aa:bb:cc:dd:ee:02 on en0 ifscope [ethernet]
  ARP

  class RecordingRunner
    attr_reader :calls

    def initialize(online, arp_output)
      @online = online
      @arp_output = arp_output
      @calls = []
    end

    def run(argv, timeout)
      @calls << { argv: argv, timeout: timeout }
      return { success: true, output: @arp_output } if argv.first == "arp"
      { success: @online.include?(argv.last), output: "" }
    end
  end

  def test_scan_pings_and_reads_the_arp_table
    scanner, = build_scanner(["192.168.33.1"], [])
    records = scanner.scan
    answered = records.find { |record| record[:ip] == "192.168.33.1" }
    assert answered[:online]
    arp_only = records.find { |record| record[:ip] == "192.168.33.2" }
    assert_equal "aa:bb:cc:dd:ee:02", arp_only[:mac]
    refute arp_only[:online]
  end

  def test_ping_uses_an_argument_array_and_the_deadline
    scanner, runner = build_scanner([], [])
    scanner.scan
    ping = runner.calls.find { |call| call[:argv].first == "ping" }
    assert_equal ["ping", "-c", "1", "-W"], ping[:argv][0, 4]
    assert_equal "2000", ping[:argv][4]
    assert_equal 3, ping[:timeout]
  end

  def test_check_ports_returns_the_open_ports
    scanner, = build_scanner([], [80, 443])
    assert_equal [80, 443], scanner.check_ports("192.168.33.1")
  end

  private

  def build_scanner(online, open_ports)
    config = Agent::Config.new("scan_range" => "192.168.33.0/30", "ping_timeout" => 2)
    runner = RecordingRunner.new(online, ARP_OUTPUT)
    connector = AgentTest::FakeConnector.new(open_ports)
    [Agent::Scanner.new(config, runner, connector), runner]
  end
end
