require_relative "test_helper"

class ModelMonitorTest < Minitest::Test
  def test_initial_value_is_unknown
    monitor = Agent::ModelMonitor.new(AgentTest::FakeLlm.new)
    assert_nil monitor.reachable
  end

  def test_a_good_check_sets_true
    monitor = Agent::ModelMonitor.new(AgentTest::FakeLlm.new(reachable: true))
    monitor.check
    assert monitor.reachable
  end

  def test_a_failed_check_sets_false
    monitor = Agent::ModelMonitor.new(AgentTest::FakeLlm.new(reachable: false))
    monitor.check
    refute monitor.reachable
  end

  def test_reading_reachable_never_calls_the_model_host
    llm = AgentTest::FakeLlm.new
    monitor = Agent::ModelMonitor.new(llm)
    5.times { monitor.reachable }
    assert_equal 0, llm.checks
  end

  def test_start_checks_in_the_background
    queue = Queue.new
    monitor = Agent::ModelMonitor.new(AgentTest::FakeLlm.new(queue: queue), 0.01)
    monitor.start
    queue.pop
    monitor.stop
    assert true
  end
end
