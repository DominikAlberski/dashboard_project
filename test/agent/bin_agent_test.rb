require_relative "test_helper"
require "open3"
require "rbconfig"
require "tempfile"

class BinAgentTest < Minitest::Test
  def test_a_bad_config_exits_with_code_1_and_the_rule
    Tempfile.create(["agent", ".yml"]) do |file|
      file.write("port: 0\n")
      file.flush
      _out, err, status = run_agent(file.path)
      assert_equal 1, status.exitstatus
      assert_match "port", err
      assert_match "1 to 65535", err
    end
  end

  private

  def run_agent(path)
    script = File.join(AgentTest::ROOT, "bin", "agent")
    Open3.capture3({ "AGENT_CONFIG" => path }, RbConfig.ruby, script, chdir: Dir.tmpdir)
  end
end
