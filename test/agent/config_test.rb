require_relative "test_helper"

class ConfigTest < Minitest::Test
  def test_defaults
    config = Agent::Config.new
    assert_equal "0.0.0.0", config.bind
    assert_equal 4567, config.port
    assert_equal "192.168.33.0/24", config.scan_range
    assert_equal 30, config.scan_interval
    assert_equal 1, config.ping_timeout
    assert_equal [22, 80, 443, 445, 3389, 5900, 11_434], config.ports
  end

  def test_model_defaults
    config = Agent::Config.new
    assert_equal "http://192.168.33.34:11434", config.model_host
    assert_equal "qwen3.8-ridge-16k:latest", config.model_name
    assert_equal 170, config.model_timeout
    assert_equal "config/devices.yml", config.devices_file
  end

  def test_loads_the_config_file
    config = Agent::Config.load(File.join(AgentTest::ROOT, "config/agent.yml"))
    assert_equal 4567, config.port
    assert_equal "qwen3.8-ridge-16k:latest", config.model_name
  end

  # Config validates at construction, so a bad value stops the agent before it binds.
  def test_rejects_bad_port_before_bind
    error = assert_raises(Agent::Config::Error) { Agent::Config.new("port" => 0) }
    assert_match "port", error.message
    assert_match "1 to 65535", error.message
  end

  def test_rejects_bad_bind
    assert_raises(Agent::Config::Error) { Agent::Config.new("bind" => "localhost") }
  end

  def test_rejects_a_cidr_bind
    assert_raises(Agent::Config::Error) { Agent::Config.new("bind" => "0.0.0.0/24") }
  end

  def test_rejects_bad_scan_range
    assert_raises(Agent::Config::Error) { Agent::Config.new("scan_range" => "192.168.33.0/23") }
  end

  def test_rejects_bad_scan_interval
    assert_raises(Agent::Config::Error) { Agent::Config.new("scan_interval" => 4) }
  end

  def test_rejects_bad_ping_timeout
    assert_raises(Agent::Config::Error) { Agent::Config.new("ping_timeout" => 6) }
  end

  def test_rejects_bad_ports
    assert_raises(Agent::Config::Error) { Agent::Config.new("ports" => [0]) }
  end

  def test_rejects_non_http_model_host
    assert_raises(Agent::Config::Error) { Agent::Config.new("model_host" => "https://example") }
  end

  def test_rejects_a_model_host_without_a_host
    assert_raises(Agent::Config::Error) { Agent::Config.new("model_host" => "http://") }
  end

  def test_rejects_a_model_host_with_a_bad_port
    assert_raises(Agent::Config::Error) { Agent::Config.new("model_host" => "http://host:99999") }
  end

  def test_rejects_empty_model_name
    assert_raises(Agent::Config::Error) { Agent::Config.new("model_name" => " ") }
  end

  def test_rejects_bad_model_timeout
    assert_raises(Agent::Config::Error) { Agent::Config.new("model_timeout" => 9) }
  end

  def test_default_ports_are_frozen_and_not_shared
    first = Agent::Config.new
    assert first.values.frozen?
    assert_raises(FrozenError) { first.ports << 1234 }
    assert_equal 11_434, Agent::Config.new.ports.last
  end
end
