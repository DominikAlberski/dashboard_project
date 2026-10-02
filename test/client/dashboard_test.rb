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

  def test_key_press_does_not_call_status
    api = FakeApi.new
    dashboard, = build(api)
    dashboard.handle_key("a")
    dashboard.tick
    assert_equal 0, api.status_calls
  end

  def test_status_poller_polls_and_pushes
    api = FakeApi.new
    api.devices = [{ "name" => "pc" }]
    queue = Queue.new
    poller = StatusPoller.new(api, queue)
    poller.start
    wait_until { !queue.empty? }
    poller.stop
    type, payload = queue.pop
    assert_equal :status, type
    assert_equal 1, payload["devices"].size
  end

  def test_status_poller_interval_is_four_seconds
    assert_equal 4, StatusPoller::INTERVAL
  end

  def test_status_update_during_chat_wait
    api = FakeApi.new
    api.gate = Queue.new
    api.devices = [{ "name" => "pc" }]
    dashboard, = build(api)
    dashboard.submit("hi")
    wait_until { api.chat_calls == 1 }
    dashboard.poll_status
    dashboard.tick
    assert_equal 1, dashboard.state[:devices].size
    assert dashboard.state[:thinking]
    api.gate << true
  end

  def test_thinking_status_shows_elapsed_seconds
    api = FakeApi.new
    api.gate = Queue.new
    dashboard, = build(api)
    dashboard.submit("hi")
    wait_until { api.chat_calls == 1 }
    assert_match(/thinking \d+s/, dashboard.state[:status])
    api.gate << true
  end

  def test_enter_during_chat_shows_waiting
    api = FakeApi.new
    api.gate = Queue.new
    dashboard, = build(api)
    dashboard.submit("hi")
    wait_until { api.chat_calls == 1 }
    dashboard.handle_key("\r")
    assert_equal "waiting for reply", dashboard.state[:status]
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

  def test_two_chats_in_sequence
    api = FakeApi.new
    api.gate = Queue.new
    api.reply = "first"
    dashboard, = build(api)
    dashboard.submit("one")
    wait_until { api.chat_calls == 1 }
    api.gate << true
    wait_until { dashboard.pending_result? }
    dashboard.tick
    assert_equal "first", dashboard.state[:reply]
    api.reply = "second"
    dashboard.submit("two")
    wait_until { api.chat_calls == 2 }
    api.gate << true
    wait_until { dashboard.pending_result? }
    dashboard.tick
    assert_equal "second", dashboard.state[:reply]
    assert_equal 2, api.chat_calls
  end

  def test_status_returns_to_device_label_after_reply
    api = FakeApi.new
    api.gate = Queue.new
    api.devices = [{ "name" => "pc" }]
    dashboard, = build(api)
    dashboard.poll_status
    dashboard.tick
    assert_equal "1 device", dashboard.state[:status]
    dashboard.submit("hi")
    wait_until { api.chat_calls == 1 }
    api.gate << true
    wait_until { dashboard.pending_result? }
    dashboard.tick
    assert_equal "1 device", dashboard.state[:status]
    refute dashboard.state[:thinking]
  end

  def test_chat_error_field_shows_error_text
    api = FakeApi.new
    api.chat_response = { "error" => "bad request" }
    dashboard, = build(api)
    dashboard.submit("hi")
    wait_until { dashboard.pending_result? }
    dashboard.tick
    assert_equal "bad request", dashboard.state[:reply]
  end

  def test_status_error_field_shows_error_text
    api = FakeApi.new
    api.status_response = { "error" => "no scan" }
    dashboard, = build(api)
    dashboard.poll_status
    dashboard.tick
    assert_equal "error: no scan", dashboard.state[:status]
  end

  def test_renders_only_after_a_state_change
    api = FakeApi.new
    api.devices = [{ "name" => "pc" }]
    dashboard, screen, = build(api)
    dashboard.poll_status
    dashboard.tick
    first = screen.draw_count
    dashboard.tick
    assert_equal first, screen.draw_count
    dashboard.handle_key("a")
    dashboard.draw
    assert_equal first + 1, screen.draw_count
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
end
