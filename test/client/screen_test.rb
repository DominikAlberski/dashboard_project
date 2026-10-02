require_relative "test_helper"

class ScreenTest < Minitest::Test
  include TestHelpers

  def setup
    @io = StringIO.new
    @screen = Screen.new(@io)
  end

  def test_renders_registered_device_by_name
    output = @screen.render(state_with(:devices => [device("nas", true)]))
    assert_includes output, "nas"
    assert_includes output, "192.168.33.5"
  end

  def test_renders_unregistered_device_by_ip
    output = @screen.render(state_with(:devices => [device("unknown", false)]))
    assert_includes output, "192.168.33.5"
    refute_includes output, "unknown"
  end

  def test_shows_empty_device_message
    assert_includes @screen.render(state_with), "(no devices)"
  end

  def test_renders_status_line
    assert_includes @screen.render(state_with(:status => "thinking 2s")), "thinking 2s"
  end

  def test_sanitizes_reply
    output = @screen.render(state_with(:reply => "hi\e[31mred"))
    refute_includes output, "\e"
    assert_includes output, "hi"
  end

  def test_sanitizes_status_error
    output = @screen.render(state_with(:status => "error\e[2Jboom"))
    refute_includes output, "\e"
    assert_includes output, "error"
  end

  def test_sanitizes_device_name
    output = @screen.render(state_with(:devices => [device("na\e[2Jme", true)]))
    refute_includes output, "\e"
    assert_includes output, "name"
  end

  def test_sanitizes_device_ip
    output = @screen.render(state_with(:devices => [device("x", false, "1\e[2J.2")]))
    refute_includes output, "\e"
  end

  def device(name, registered, ip = "192.168.33.5")
    { "name" => name, "ip" => ip, "online" => true, "registered" => registered }
  end
end
