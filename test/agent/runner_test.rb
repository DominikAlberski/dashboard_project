require_relative "test_helper"
require "rbconfig"

class RunnerTest < Minitest::Test
  def test_success_returns_the_output
    result = Agent::Runner.new.run(["printf", "hi"], 2)
    assert result[:success]
    assert_equal "hi", result[:output]
  end

  def test_deadline_kills_the_process
    started = Time.now
    result = Agent::Runner.new.run(["sleep", "5"], 0.2)
    refute result[:success]
    assert_operator Time.now - started, :<, 3
  end

  # The child closes its output and then sleeps, so only the wait needs the deadline.
  def test_deadline_covers_the_wait_for_the_process
    script = "$stdout.close\n$stderr.close\nsleep 5"
    started = Time.now
    result = Agent::Runner.new.run([RbConfig.ruby, "-e", script], 0.3)
    refute result[:success]
    assert_operator Time.now - started, :<, 3
  end
end
