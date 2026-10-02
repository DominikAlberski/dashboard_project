require_relative "test_helper"

class SnapshotMergeTest < Minitest::Test
  MAC_FIRST = [
    { ip: "192.168.33.99", mac: "AA:BB:CC:DD:EE:01", online: true },
    { ip: "192.168.33.11", mac: "AA:BB:CC:DD:EE:99", online: true },
    { ip: "192.168.33.50", mac: "AA:BB:CC:DD:EE:50", online: true }
  ].freeze

  def test_merge_matches_by_mac_first
    pc = device(merge(MAC_FIRST), "pc")
    assert_equal "192.168.33.99", pc[:ip]
    assert pc[:online]
  end

  def test_merge_matches_a_moved_device_by_ip
    assert device(merge(MAC_FIRST), "nas")[:online]
  end

  def test_merge_lists_an_unregistered_online_address
    extra = merge(MAC_FIRST).find { |item| item[:registered] == false }
    assert_nil extra[:name]
    assert_equal "192.168.33.50", extra[:ip]
  end

  def test_an_arp_entry_without_a_ping_answer_is_offline
    records = [{ ip: "192.168.33.10", mac: "AA:BB:CC:DD:EE:01", online: false }]
    refute device(merge(records), "pc")[:online]
  end

  # Device b takes the old address of device a. The MAC match must win once.
  def test_dhcp_reassignment_between_two_registry_devices
    devices = Agent::DeviceMerge.new(dhcp_registry).merge(dhcp_records)
    assert_equal 2, devices.size
    refute devices.find { |item| item[:name] == "a" }[:online]
    assert devices.find { |item| item[:name] == "b" }[:online]
  end

  private

  def merge(records)
    Agent::DeviceMerge.new(AgentTest.device_registry).merge(records)
  end

  def device(devices, name)
    devices.find { |item| item[:name] == name }
  end

  def dhcp_records
    [{ ip: "192.168.33.10", mac: "BB:BB:BB:BB:BB:BB", online: true }]
  end

  def dhcp_registry
    Agent::Registry.new(
      [
        { "name" => "a", "mac" => "AA:AA:AA:AA:AA:AA", "ip" => "192.168.33.10" },
        { "name" => "b", "mac" => "BB:BB:BB:BB:BB:BB", "ip" => "192.168.33.20" }
      ]
    )
  end
end
