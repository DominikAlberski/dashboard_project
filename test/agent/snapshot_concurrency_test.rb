require_relative "test_helper"

class SnapshotConcurrencyTest < Minitest::Test
  GATED_RECORDS = [
    [{ ip: "192.168.33.10", mac: "AA:BB:CC:DD:EE:01", online: true }],
    [{ ip: "192.168.33.99", mac: "AA:BB:CC:DD:EE:01", online: true }]
  ].freeze

  class PeakTracker
    attr_reader :max

    def initialize
      @active = 0
      @max = 0
      @mutex = Mutex.new
    end

    def enter
      @mutex.synchronize do
        @active += 1
        @max = [@max, @active].max
      end
    end

    def leave
      @mutex.synchronize { @active -= 1 }
    end
  end

  def test_one_scan_runs_at_a_time
    peak = PeakTracker.new
    snapshot = snapshot_for(peak_scanner(peak))
    threads = Array.new(4) { Thread.new { snapshot.scan_now } }
    threads.each(&:join)
    assert_equal 1, peak.max
  end

  def test_a_waiting_request_gets_the_running_result
    scanner = AgentTest::BehaviorScanner.new do
      sleep 0.2
      GATED_RECORDS[0]
    end
    snapshot = snapshot_for(scanner)
    first = Thread.new { snapshot.scan_now }
    sleep 0.05
    second = snapshot.scan_now
    assert_equal 1, scanner.calls
    assert_equal first.value[:devices], second[:devices]
  end

  def test_both_waiters_get_the_same_scan_response
    first, second, = wait_pair
    assert_same first, second
    assert_equal "192.168.33.10", device_ip(first, "pc")
  end

  # A later scan completes, then the delayed caller still holds the first result.
  def test_a_delayed_caller_keeps_the_first_scan_result
    first, _second, snapshot, gates = wait_pair
    gates[1] << true
    assert_equal "192.168.33.10", device_ip(first, "pc")
    assert_equal "192.168.33.99", device_ip(snapshot.scan_now, "pc")
  end

  private

  def wait_pair
    gates = [Queue.new, Queue.new]
    started = Queue.new
    snapshot = snapshot_for(gated_scanner(gates, started))
    first = Thread.new { snapshot.scan_now }
    started.pop
    second = Thread.new { snapshot.scan_now }
    Thread.pass until second.status == "sleep"
    gates[0] << true
    [first.value, second.value, snapshot, gates]
  end

  def peak_scanner(peak)
    AgentTest::BehaviorScanner.new do
      peak.enter
      sleep 0.1
      peak.leave
      []
    end
  end

  def gated_scanner(gates, started)
    scanner = AgentTest::BehaviorScanner.new do
      index = scanner.calls - 1
      started << index
      gates[index].pop
      GATED_RECORDS[index]
    end
    scanner
  end

  def device_ip(response, name)
    response[:devices].find { |device| device[:name] == name }[:ip]
  end

  def snapshot_for(scanner)
    Agent::Snapshot.new(AgentTest.device_registry, scanner, Agent::Config.new("scan_interval" => 5))
  end
end
