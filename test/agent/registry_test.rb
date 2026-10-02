require_relative "test_helper"

class RegistryTest < Minitest::Test
  DEVICES = [
    { "name" => "pc", "mac" => "aa:bb:cc:dd:ee:01", "ip" => "192.168.33.10" },
    { "name" => "mac", "mac" => "AA-BB-CC-DD-EE-02", "ip" => "192.168.33.11" }
  ].freeze

  def test_find_is_case_insensitive
    registry = Agent::Registry.new(DEVICES)
    assert_equal "pc", registry.find("PC")[:name]
    assert_nil registry.find("missing")
    assert_nil registry.find(nil)
  end

  def test_normalizes_the_mac
    registry = Agent::Registry.new(DEVICES)
    assert_equal "AA:BB:CC:DD:EE:02", registry.find("mac")[:mac]
  end

  def test_loads_the_devices_file
    registry = Agent::Registry.load(File.join(AgentTest::ROOT, "config/devices.yml"))
    refute_empty registry.devices
  end

  def test_rejects_a_bad_name
    assert_raises(Agent::Registry::Error) { Agent::Registry.new([device("name" => "-bad")]) }
  end

  def test_rejects_a_bad_mac
    assert_raises(Agent::Registry::Error) { Agent::Registry.new([device("mac" => "zz")]) }
  end

  def test_rejects_a_bad_ip
    assert_raises(Agent::Registry::Error) { Agent::Registry.new([device("ip" => "999.1.1.1")]) }
  end

  def test_rejects_a_cidr_ip
    assert_raises(Agent::Registry::Error) { Agent::Registry.new([device("ip" => "192.168.33.10/24")]) }
  end

  def test_rejects_duplicate_names
    duplicate = DEVICES + [device("name" => "PC", "mac" => "AA:BB:CC:DD:EE:03")]
    assert_raises(Agent::Registry::Error) { Agent::Registry.new(duplicate) }
  end

  private

  def device(overrides)
    { "name" => "pc", "mac" => "AA:BB:CC:DD:EE:01", "ip" => "192.168.33.10" }.merge(overrides)
  end
end
