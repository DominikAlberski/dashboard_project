require_relative "test_helper"

class ChatFlowTest < Minitest::Test
  include TestHelpers

  def test_one_chat_request_at_a_time
    api = FakeApi.new
    api.gate = Queue.new
    dashboard, = build_dashboard(api)
    submit_chat(api, dashboard, "one")
    dashboard.submit("two")
    dashboard.submit("three")
    assert_equal 1, api.chat_calls
    api.gate << true
  end

  def test_two_chats_in_sequence
    api = FakeApi.new
    api.gate = Queue.new
    api.reply = "first"
    dashboard, = build_dashboard(api)
    deliver_chat(api, dashboard, "one", 1)
    assert_equal "first", dashboard.state[:reply]
    api.reply = "second"
    deliver_chat(api, dashboard, "two", 2)
    assert_equal "second", dashboard.state[:reply]
  end

  def test_thinking_status_shows_elapsed_seconds
    api = FakeApi.new
    api.gate = Queue.new
    dashboard, = build_dashboard(api)
    submit_chat(api, dashboard, "hi")
    assert_match(/thinking \d+s/, dashboard.state[:status])
    api.gate << true
  end

  def test_enter_during_chat_shows_waiting
    api = FakeApi.new
    api.gate = Queue.new
    dashboard, = build_dashboard(api)
    submit_chat(api, dashboard, "hi")
    dashboard.handle_key("\r")
    assert_equal "waiting for reply", dashboard.state[:status]
    api.gate << true
  end

  def test_chat_result_applied_by_main_thread_drain
    api = FakeApi.new
    api.reply = "hello"
    api.gate = Queue.new
    dashboard, = build_dashboard(api)
    submit_chat(api, dashboard, "hi")
    release_chat(api, dashboard)
    assert_equal "", dashboard.state[:reply]
    dashboard.tick
    assert_equal "hello", dashboard.state[:reply]
  end

  def test_status_returns_to_device_label_after_reply
    api = FakeApi.new
    api.gate = Queue.new
    api.devices = [{ "name" => "pc" }]
    dashboard, = build_dashboard(api)
    refresh(dashboard)
    assert_equal "1 device", dashboard.state[:status]
    deliver_chat(api, dashboard, "hi", 1)
    assert_equal "1 device", dashboard.state[:status]
    refute dashboard.state[:thinking]
  end

  def test_chat_error_field_shows_error_text
    api = FakeApi.new
    api.chat_response = { "error" => "bad request" }
    dashboard, = build_dashboard(api)
    dashboard.submit("hi")
    wait_until { dashboard.pending_result? }
    dashboard.tick
    assert_equal "bad request", dashboard.state[:reply]
  end
end
