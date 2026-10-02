require_relative "test_helper"

class SnapshotTest < Minitest::Test
  GOOD_RECORDS = [{ ip: "192.168.33.10", mac: "AA:BB:CC:DD:EE:01", online: true }].freeze

  def test_initial_state_before_the_first_scan
    status = snapshot_for(AgentTest::BehaviorScanner.new { [] }).status
    assert_equal 2, status[:devices].size
    assert(status[:devices].all? { |device| device[:registered] && !device[:online] })
    assert_nil status[:agent][:last_scan_at]
    refute status[:agent][:scanning]
    assert_nil status[:agent][:last_scan_error]
  end

  def test_a_failed_scan_keeps_the_last_good_state
    snapshot = scanning_twice([GOOD_RECORDS, :fail])
    assert_equal "arp failed", snapshot.status[:agent][:last_scan_error]
    assert device(snapshot, "pc")[:online]
  end

  def test_a_failed_scan_keeps_the_last_scan_time
    snapshot = scanning_twice([GOOD_RECORDS, :fail])
    assert snapshot.status[:agent][:last_scan_at]
  end

  def test_published_state_is_deeply_frozen
    pc = device(scan_with(GOOD_RECORDS), "pc")
    assert pc.frozen?
    assert pc[:name].frozen?
    assert_raises(FrozenError) { pc[:online] = false }
  end

  def test_published_state_is_isolated_from_scanner_records
    record = { ip: "192.168.33.10", mac: "AA:BB:CC:DD:EE:01", online: true }
    snapshot = scan_with([record])
    record[:online] = false
    assert device(snapshot, "pc")[:online]
  end

  private

  def scan_with(records)
    snapshot = snapshot_for(AgentTest::BehaviorScanner.new { records })
    snapshot.scan_now
    snapshot
  end

  def scanning_twice(outcomes)
    scanner = AgentTest::BehaviorScanner.new do
      outcome = outcomes.shift
      raise Agent::Scanner::Error, "arp failed" if outcome == :fail
      outcome
    end
    snapshot = snapshot_for(scanner)
    2.times { snapshot.scan_now }
    snapshot
  end

  def device(snapshot, name)
    snapshot.status[:devices].find { |item| item[:name] == name }
  end

  def snapshot_for(scanner)
    Agent::Snapshot.new(AgentTest.device_registry, scanner, Agent::Config.new("scan_interval" => 5))
  end
end
