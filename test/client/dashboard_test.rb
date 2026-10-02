require_relative "test_helper"

class DashboardTest < Minitest::Test
  include TestHelpers

  def build(api = FakeApi.new, input = FakeInput.new)
    screen = FakeScreen.new
    [Dashboard.new(api, screen, input), screen, input]
  end

  def test_enter_submits_chat_and_clears_input
    api = FakeApi.new
    dashboard, = build(api)
    dashboard.handle_key("h")
    dashboard.handle_key("i")
    assert_equal "hi", dashboard.state[:input]
    dashboard.handle_key("\r")
    wait_until { api.chat_calls == 1 }
    assert_equal "hi", api.last_text
    assert_equal "", dashboard.state[:input]
  end

  def test_one_chat_request_at_a_time
    api = FakeApi.new
    api.gate = Queue.new
    dashboard, = build(api)
    dashboard.submit("one")
    wait_until { api.chat_calls == 1 }
    dashboard.submit("two")
    dashboard.submit("three")
    assert_equal 1, api.chat_calls
    api.gate << true
  end

  def test_status_polls_continue_during_chat_wait
    api = FakeApi.new
    api.gate = Queue.new
    dashboard, = build(api)
    dashboard.submit("hi")
    wait_until { api.chat_calls == 1 }
    before = api.status_calls
    3.times { dashboard.tick }
    assert_equal before + 3, api.status_calls
    assert dashboard.state[:thinking]
    api.gate << true
  end

  def test_chat_result_applied_by_main_thread_drain
    api = FakeApi.new
    api.reply = "hello"
    api.gate = Queue.new
    dashboard, = build(api)
    dashboard.submit("hi")
    wait_until { api.chat_calls == 1 }
    api.gate << true
    wait_until { dashboard.pending_result? }
    assert_equal "", dashboard.state[:reply]
    dashboard.tick
    assert_equal "hello", dashboard.state[:reply]
    refute dashboard.state[:thinking]
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

  def test_backspace_removes_last_character
    dashboard, = build
    dashboard.handle_key("a")
    dashboard.handle_key("b")
    dashboard.handle_key("\b")
    assert_equal "a", dashboard.state[:input]
  end

  def test_q_inside_text_does_not_quit
    dashboard, = build
    dashboard.handle_key("a")
    dashboard.handle_key("q")
    assert_equal "aq", dashboard.state[:input]
  end

  def test_terminal_restored_on_exception
    input = RaisingInput.new
    dashboard = Dashboard.new(FakeApi.new, FakeScreen.new, input)
    assert_raises(RuntimeError) { dashboard.run }
    assert_equal 1, input.restore_count
  end

  def test_renders_only_after_a_state_change
    api = FakeApi.new
    dashboard, screen, = build(api)
    dashboard.tick
    first = screen.draw_count
    dashboard.tick
    assert_equal first, screen.draw_count
    dashboard.handle_key("a")
    dashboard.draw
    assert_equal first + 1, screen.draw_count
  end

  def test_unreachable_agent_shows_error_status
    api = FakeApi.new
    api.status_error = RuntimeError.new("down")
    dashboard, = build(api)
    dashboard.tick
    assert_includes dashboard.state[:status], "error"
  end
end
