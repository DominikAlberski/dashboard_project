require_relative "test_helper"
require_relative "../../client/page"

class PageTest < Minitest::Test
  def test_renders_registered_device_by_name
    html = Page.new(devices: [device("nas", true)], reply: nil, model: model).to_html
    assert_includes html, "nas"
    assert_includes html, "192.168.33.5"
  end

  def test_renders_unregistered_device_by_ip
    html = Page.new(devices: [device("unknown", false)], reply: nil, model: model).to_html
    assert_includes html, "192.168.33.5"
    refute_includes html, "unknown"
    refute_match(/192\.168\.33\.5 192\.168\.33\.5/, html)
  end

  def test_shows_empty_device_message
    html = Page.new(devices: [], reply: nil, model: model).to_html
    assert_includes html, "(no devices)"
  end

  def test_renders_the_reply
    html = Page.new(devices: [], reply: "10 devices", model: model).to_html
    assert_includes html, "10 devices"
  end

  def test_hides_the_reply_when_empty
    html = Page.new(devices: [], reply: nil, model: model).to_html
    refute_includes html, 'class="reply"'
  end

  def test_renders_the_model_reachable
    html = Page.new(devices: [], reply: nil, model: model("qwen", true)).to_html
    assert_includes html, "qwen"
    assert_includes html, "online"
  end

  def test_renders_the_model_offline
    html = Page.new(devices: [], reply: nil, model: model("qwen", false)).to_html
    assert_includes html, "offline"
  end

  def test_escapes_html_in_device_name
    html = Page.new(devices: [device("<b>bad</b>", true)], reply: nil, model: model).to_html
    refute_includes html, "<b>bad</b>"
    assert_includes html, "&lt;b&gt;bad&lt;/b&gt;"
  end

  def test_escapes_html_in_the_reply
    html = Page.new(devices: [], reply: "<script>x</script>", model: model).to_html
    refute_includes html, "<script>"
  end

  def test_error_page_escapes_the_message
    html = Page.error("no <b>agent</b>")
    assert_includes html, "&lt;b&gt;agent&lt;/b&gt;"
  end

  def test_renders_a_form_and_meta_refresh
    html = Page.new(devices: [], reply: nil, model: model).to_html
    assert_includes html, "method=\"post\""
    assert_includes html, "http-equiv=\"refresh\""
  end

  private

  def device(name, registered, ip = "192.168.33.5")
    { "name" => name, "ip" => ip, "online" => true, "registered" => registered }
  end

  def model(name = "qwen", reachable = true)
    { "name" => name, "reachable" => reachable }
  end
end
