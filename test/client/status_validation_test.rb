require_relative "test_helper"

class StatusValidationTest < Minitest::Test
  include TestHelpers

  def test_null_devices_keeps_last_devices
    api, dashboard = setup_dashboard
    api.status_response = { "devices" => nil }
    refresh(dashboard)
    assert_equal 1, dashboard.state[:devices].size
    assert_includes dashboard.state[:status], "error"
  end

  def test_missing_devices_keeps_last_devices
    api, dashboard = setup_dashboard
    api.status_response = {}
    refresh(dashboard)
    assert_equal 1, dashboard.state[:devices].size
    assert_includes dashboard.state[:status], "error"
  end

  def test_error_object_keeps_last_devices
    api, dashboard = setup_dashboard
    api.status_response = { "error" => "no scan" }
    refresh(dashboard)
    assert_equal 1, dashboard.state[:devices].size
    assert_equal "error: no scan", dashboard.state[:status]
  end

  def setup_dashboard
    api = FakeApi.new
    api.devices = [{ "name" => "pc" }]
    dashboard, = build_dashboard(api)
    refresh(dashboard)
    [api, dashboard]
  end
end
