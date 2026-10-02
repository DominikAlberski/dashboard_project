require_relative "test_helper"

class SnapshotTest < Minitest::Test
  GOOD_RECORDS = [{ ip: "192.168.33.10", mac: "AA:BB:CC:DD:EE:01", online: true }].freeze

  # Each call gives a distinct timestamp, so a failed scan cannot hide a new one.
  class StepClock
    def initialize(start)
      @time = start
    end

    def call
      value = @time
      @time += 10
      value
    end
  end

  def test_initial_state_before_the_first_scan
    agent = snapshot_for(AgentTest::BehaviorScanner.new { [] }).status[:agent]
    assert_nil agent[:last_scan_at]
    refute agent[:scanning]
    assert_nil agent[:last_scan_error]
  end

  def test_initial_devices_are_offline
    devices = snapshot_for(AgentTest::BehaviorScanner.new { [] }).status[:devices]
    assert_equal 2, devices.size
    assert(devices.all? { |device| device[:registered] && !device[:online] })
  end

  def test_a_failed_scan_keeps_the_last_good_state
    snapshot = scanning_twice([GOOD_RECORDS, :fail])
    assert_equal "arp failed", snapshot.status[:agent][:last_scan_error]
    assert device(snapshot, "pc")[:online]
  end

  def test_a_failed_scan_keeps_the_last_scan_timestamp
    snapshot = scanning_twice([GOOD_RECORDS, :fail], StepClock.new(Time.utc(2026, 1, 1)))
    expected = Time.utc(2026, 1, 1, 0, 0, 10).iso8601
    assert_equal expected, snapshot.status[:agent][:last_scan_at]
  end

  def test_agent_metadata_strings_are_frozen
    agent = scan_with(GOOD_RECORDS).status[:agent]
    assert agent[:started_at].frozen?
    assert agent[:last_scan_at].frozen?
    assert_raises(FrozenError) { agent[:last_scan_at].replace("wrong") }
  end

  def test_the_initial_started_at_is_frozen
    agent = snapshot_for(AgentTest::BehaviorScanner.new { [] }).status[:agent]
    assert agent[:started_at].frozen?
  end

  def test_the_error_text_is_frozen
    agent = scanning_twice([GOOD_RECORDS, :fail]).status[:agent]
    assert agent[:last_scan_error].frozen?
  end

  def test_published_devices_are_deeply_frozen
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

  def test_start_scans_at_once
    started = Queue.new
    snapshot = snapshot_for(started_scanner(started))
    snapshot.start
    started.pop
    assert snapshot.status[:agent][:last_scan_at]
  ensure
    snapshot&.stop
  end

  private

  def started_scanner(started)
    AgentTest::BehaviorScanner.new do
      started << true
      []
    end
  end

  def scan_with(records)
    snapshot = snapshot_for(AgentTest::BehaviorScanner.new { records })
    snapshot.scan_now
    snapshot
  end

  def scanning_twice(outcomes, clock = nil)
    scanner = AgentTest::BehaviorScanner.new do
      outcome = outcomes.shift
      raise Agent::Scanner::Error, "arp failed" if outcome == :fail
      outcome
    end
    snapshot = snapshot_for(scanner, clock)
    2.times { snapshot.scan_now }
    snapshot
  end

  def device(snapshot, name)
    snapshot.status[:devices].find { |item| item[:name] == name }
  end

  def snapshot_for(scanner, clock = nil)
    Agent::Snapshot.new(AgentTest.device_registry, scanner, Agent::Config.new("scan_interval" => 5),
                        clock || -> { Time.now })
  end
end
