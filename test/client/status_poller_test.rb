require_relative "test_helper"

class StatusPollerTest < Minitest::Test
  include TestHelpers

  def test_polls_and_pushes_status
    api = FakeApi.new
    api.devices = [{ "name" => "pc" }]
    queue = Queue.new
    poller = StatusPoller.new(api, queue)
    poller.start
    wait_until { !queue.empty? }
    poller.stop
    type, payload = queue.pop
    assert_equal :status, type
    assert_equal 1, payload["devices"].size
  end

  def test_interval_is_four_seconds
    assert_equal 4, StatusPoller::INTERVAL
  end

  def test_keeps_four_second_cadence
    clock = FakeClock.new
    api = FakeApi.new
    api.clock = clock
    api.status_delay = 2
    poller = StatusPoller.new(api, Queue.new, clock)
    poller.wait_for_next
    poller.wait_for_next
    assert_equal [0, 4], api.status_starts
    assert_equal [2, 2], clock.sleeps
  end

  def test_skips_missed_deadline
    clock = FakeClock.new
    api = FakeApi.new
    api.clock = clock
    api.status_delay = 6
    poller = StatusPoller.new(api, Queue.new, clock)
    poller.wait_for_next
    assert_equal [], clock.sleeps
    assert_equal 6, clock.now
  end

  def test_converts_a_non_hash_to_error
    queue = Queue.new
    api = FakeApi.new
    api.status_response = [1, 2]
    StatusPoller.new(api, queue, FakeClock.new).wait_for_next
    assert queue.pop.last["error"]
  end

  def test_converts_null_device_to_error
    queue = Queue.new
    api = FakeApi.new
    api.status_response = { "devices" => [nil] }
    StatusPoller.new(api, queue, FakeClock.new).wait_for_next
    assert queue.pop.last["error"]
  end

  def test_accepts_valid_devices
    queue = Queue.new
    api = FakeApi.new
    api.status_response = { "devices" => [{ "name" => "pc" }] }
    StatusPoller.new(api, queue, FakeClock.new).wait_for_next
    assert_equal "pc", queue.pop.last["devices"].first["name"]
  end
end
