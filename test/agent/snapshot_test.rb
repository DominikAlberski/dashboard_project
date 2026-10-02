require_relative "test_helper"

class SnapshotTest < Minitest::Test
  class BehaviorScanner
    attr_reader :calls

    def initialize(&block)
      @block = block
      @calls = 0
    end

    def scan
      @calls += 1
      @block.call
    end
  end

  def test_initial_state_before_the_first_scan
    snapshot = snapshot_for(BehaviorScanner.new { [] })
    status = snapshot.status
    assert_equal 2, status[:devices].size
    assert(status[:devices].all? { |device| device[:registered] && !device[:online] })
    assert_nil status[:agent][:last_scan_at]
    refute status[:agent][:scanning]
    assert_nil status[:agent][:last_scan_error]
  end

  def test_merge_matches_by_mac_first_then_ip
    records = [
      { ip: "192.168.33.99", mac: "AA:BB:CC:DD:EE:01", online: true },
      { ip: "192.168.33.11", mac: "AA:BB:CC:DD:EE:99", online: true },
      { ip: "192.168.33.50", mac: "AA:BB:CC:DD:EE:50", online: true }
    ]
    snapshot = snapshot_for(BehaviorScanner.new { records })
    snapshot.scan_now
    devices = snapshot.status[:devices]
    assert_equal 3, devices.size
    assert_equal "192.168.33.99", devices.find { |d| d[:name] == "pc" }[:ip]
    assert devices.find { |d| d[:name] == "nas" }[:online]
    extra = devices.find { |device| device[:registered] == false }
    assert_nil extra[:name]
    assert_equal "192.168.33.50", extra[:ip]
  end

  def test_an_arp_entry_without_a_ping_answer_is_offline
    records = [{ ip: "192.168.33.10", mac: "AA:BB:CC:DD:EE:01", online: false }]
    snapshot = snapshot_for(BehaviorScanner.new { records })
    snapshot.scan_now
    pc = snapshot.status[:devices].find { |device| device[:name] == "pc" }
    refute pc[:online]
  end

  def test_one_scan_runs_at_a_time
    active = 0
    peak = 0
    guard = Mutex.new
    scanner = BehaviorScanner.new do
      guard.synchronize { active += 1; peak = [peak, active].max }
      sleep 0.1
      guard.synchronize { active -= 1 }
      []
    end
    snapshot = snapshot_for(scanner)
    threads = Array.new(4) { Thread.new { snapshot.scan_now } }
    threads.each(&:join)
    assert_equal 1, peak
  end

  def test_a_waiting_request_gets_the_running_result
    scanner = BehaviorScanner.new do
      sleep 0.2
      [{ ip: "192.168.33.10", mac: "AA:BB:CC:DD:EE:01", online: true }]
    end
    snapshot = snapshot_for(scanner)
    first = Thread.new { snapshot.scan_now }
    sleep 0.05
    second = snapshot.scan_now
    assert_equal 1, scanner.calls
    assert_equal first.value[:devices], second[:devices]
    assert second[:devices].first[:online]
  end

  def test_a_failed_scan_keeps_the_last_good_state
    outcomes = [
      [{ ip: "192.168.33.10", mac: "AA:BB:CC:DD:EE:01", online: true }],
      :fail
    ]
    scanner = BehaviorScanner.new do
      outcome = outcomes.shift
      raise "scan failed" if outcome == :fail
      outcome
    end
    snapshot = snapshot_for(scanner)
    snapshot.scan_now
    good = snapshot.status
    snapshot.scan_now
    after = snapshot.status
    assert_equal good[:devices], after[:devices]
    assert_equal good[:agent][:last_scan_at], after[:agent][:last_scan_at]
    assert_equal "scan failed", after[:agent][:last_scan_error]
    assert after[:devices].find { |device| device[:name] == "pc" }[:online]
  end

  def test_publish_replaces_the_state_atomically
    records = [{ ip: "192.168.33.10", mac: "AA:BB:CC:DD:EE:01", online: true }]
    snapshot = snapshot_for(BehaviorScanner.new { records })
    before = snapshot.status
    snapshot.scan_now
    after = snapshot.status
    assert after.frozen?
    assert after[:devices].frozen?
    assert(before[:devices].all? { |device| !device[:online] })
    assert after[:devices].find { |device| device[:name] == "pc" }[:online]
  end

  private

  def snapshot_for(scanner)
    Agent::Snapshot.new(registry, scanner, Agent::Config.new("scan_interval" => 5))
  end

  def registry
    Agent::Registry.new(
      [
        { "name" => "pc", "mac" => "AA:BB:CC:DD:EE:01", "ip" => "192.168.33.10" },
        { "name" => "nas", "mac" => "AA:BB:CC:DD:EE:02", "ip" => "192.168.33.11" }
      ]
    )
  end
end
