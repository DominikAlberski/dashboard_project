require_relative "test_helper"

class ScreenTest < Minitest::Test
  include TestHelpers

  def setup
    @io = StringIO.new
    @screen = Screen.new(@io)
  end

  def test_renders_registered_device_by_name
    device = { "name" => "nas", "ip" => "192.168.33.5",
               "online" => true, "registered" => true }
    output = @screen.render(state_with(:devices => [device]))
    assert_includes output, "nas"
    assert_includes output, "192.168.33.5"
  end

  def test_renders_unregistered_device_by_ip
    device = { "name" => "unknown", "ip" => "192.168.33.9",
               "online" => false, "registered" => false }
    output = @screen.render(state_with(:devices => [device]))
    assert_includes output, "192.168.33.9"
    refute_includes output, "unknown"
  end

  def test_shows_empty_device_message
    assert_includes @screen.render(state_with), "(no devices)"
  end

  def test_shows_thinking_indicator
    assert_includes @screen.render(state_with(:thinking => true)), "thinking"
  end

  def test_sanitizes_reply
    output = @screen.render(state_with(:reply => "hi\e[31mred"))
    refute_includes output, "\e"
    assert_includes output, "hi"
  end
end
