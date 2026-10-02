require_relative "test_helper"

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
end
