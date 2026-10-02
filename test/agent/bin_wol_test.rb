require_relative "test_helper"
require "open3"
require "rbconfig"
require "tmpdir"

class BinWolTest < Minitest::Test
  # A bad argument exits before any socket call, so this test does not touch the LAN.
  def test_a_bad_argument_exits_with_code_2
    _out, _err, status = Open3.capture3(RbConfig.ruby, "bin/wol", chdir: AgentTest::ROOT)
    assert_equal 2, status.exitstatus
  end

  # bin/wol must find config/devices.yml when the working directory is different.
  def test_a_bad_argument_exits_with_code_2_from_another_directory
    script = File.join(AgentTest::ROOT, "bin", "wol")
    _out, _err, status = Open3.capture3(RbConfig.ruby, script, chdir: Dir.tmpdir)
    assert_equal 2, status.exitstatus
  end
end
