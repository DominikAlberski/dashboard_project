require_relative "test_helper"

class DashboardTest < Minitest::Test
  include TestHelpers

  def test_enter_submits_chat_and_clears_input
    api = FakeApi.new
    dashboard, = build_dashboard(api)
    dashboard.handle_key("h")
    dashboard.handle_key("i")
    assert_equal "hi", dashboard.state[:input]
    dashboard.handle_key("\r")
    wait_until { api.chat_calls == 1 }
    assert_equal "hi", api.last_text
    assert_equal "", dashboard.state[:input]
  end

  def test_key_press_does_not_call_status
    api = FakeApi.new
    dashboard, = build_dashboard(api)
    dashboard.handle_key("a")
    dashboard.tick
    assert_equal 0, api.status_calls
  end

  def test_q_on_empty_input_quits_and_restores
    input = FakeInput.new(["q"])
    dashboard = Dashboard.new(FakeApi.new, FakeScreen.new, input)
    dashboard.run
    assert_equal 1, input.restore_count
  end

  def test_ctrl_c_quits
    input = FakeInput.new(["\u0003"])
    dashboard = Dashboard.new(FakeApi.new, FakeScreen.new, input)
    dashboard.run
    assert_equal 1, input.restore_count
  end

  def test_terminal_restored_on_exception
    input = RaisingInput.new
    dashboard = Dashboard.new(FakeApi.new, FakeScreen.new, input)
    assert_raises(RuntimeError) { dashboard.run }
    assert_equal 1, input.restore_count
  end

  def test_run_stops_the_chat_thread
    api = FakeApi.new
    api.gate = Queue.new
    input = FakeInput.new(["q"])
    dashboard = Dashboard.new(api, FakeScreen.new, input)
    dashboard.submit("hi")
    wait_until { api.chat_calls == 1 }
    dashboard.run
    wait_until { !dashboard.chat_thread.alive? }
  end

  def test_run_stops_the_chat_thread_on_input_exception
    api = FakeApi.new
    api.gate = Queue.new
    dashboard = Dashboard.new(api, FakeScreen.new, RaisingInput.new)
    dashboard.submit("hi")
    wait_until { api.chat_calls == 1 }
    assert_raises(RuntimeError) { dashboard.run }
    wait_until { !dashboard.chat_thread.alive? }
  end

  def test_renders_only_after_a_state_change
    api = FakeApi.new
    api.devices = [{ "name" => "pc" }]
    dashboard, screen, = build_dashboard(api)
    draw_after_status(dashboard)
    assert_equal 1, screen.draw_count
    dashboard.handle_key("a")
    dashboard.draw
    assert_equal 2, screen.draw_count
  end

  def test_malformed_status_keeps_last_devices_and_running
    api = FakeApi.new
    api.devices = [{ "name" => "pc" }]
    dashboard, = build_dashboard(api)
    refresh(dashboard)
    assert_equal 1, dashboard.state[:devices].size
    api.status_response = { "devices" => [nil] }
    refresh(dashboard)
    assert_equal 1, dashboard.state[:devices].size
    assert_includes dashboard.state[:status], "error"
  end
end
