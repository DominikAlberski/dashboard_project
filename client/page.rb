class Page
  REFRESH = 10

  def initialize(devices:, reply:, model:)
    @devices = devices
    @reply = reply
    @model = model
  end

  def to_html
    [head, "<body>", header, model_line, device_list, reply_block, form,
     "</body></html>"].flatten.join("\n")
  end

  def self.error(message)
    "<!DOCTYPE html>\n<html lang=\"en\"><head><meta charset=\"utf-8\">" \
      "<title>LAN dashboard</title></head><body><h1>LAN dashboard</h1>" \
      "<p class=\"note\">#{escape(message)}</p></body></html>"
  end

  def self.escape(text)
    text.to_s.gsub("&", "&amp;").gsub("<", "&lt;").gsub(">", "&gt;")
             .gsub('"', "&quot;")
  end

  private

  def head
    ["<!DOCTYPE html>", "<html lang=\"en\">", "<head>", "<meta charset=\"utf-8\">",
     "<meta name=\"viewport\" content=\"width=device-width, initial-scale=1\">",
     "<meta name=\"apple-mobile-web-app-capable\" content=\"yes\">",
     "<meta name=\"apple-mobile-web-app-status-bar-style\" content=\"black\">",
     "<meta http-equiv=\"refresh\" content=\"#{REFRESH}\">",
     "<title>LAN dashboard</title>", "<style>", STYLES, "</style>", "</head>"]
  end

  def header
    ["<h1>LAN dashboard</h1>", "<p class=\"count\">#{device_count}</p>"]
  end

  def device_count
    "#{@devices.size} devices"
  end

  def model_line
    reachable = @model.fetch("reachable", false) ? "online" : "offline"
    "<p class=\"model\">model #{Page.escape(@model.fetch('name', ''))} #{reachable}</p>"
  end

  def device_list
    return ["<p>(no devices)</p>"] if @devices.empty?
    ["<ul>", @devices.map { |device| device_row(device) }, "</ul>"]
  end

  def device_row(device)
    mark = device["online"] ? "\u25CF" : "\u25CB"
    "<li>#{mark} #{device_label(device)}</li>"
  end

  def device_label(device)
    return Page.escape(device["ip"].to_s) unless device["registered"]
    "#{Page.escape(device['name'].to_s)} #{Page.escape(device['ip'].to_s)}"
  end

  def reply_block
    return [] if @reply.nil? || @reply.empty?
    ["<p class=\"reply\">#{Page.escape(@reply)}</p>"]
  end

  def form
    ["<form method=\"post\" action=\"/\">",
     "<input type=\"text\" name=\"text\" placeholder=\"ask the LAN\">",
     "<button type=\"submit\">Ask</button>", "</form>"]
  end

  STYLES = <<~CSS.freeze
    body { font: 15px Helvetica, Arial, sans-serif; margin: 0; padding: 12px; color: #111; background: #fff; }
    h1 { font-size: 16px; margin: 0 0 2px; color: #333; }
    .count { color: #666; margin: 0 0 8px; }
    .model { color: #666; font-size: 13px; margin: 0 0 10px; }
    ul { list-style: none; margin: 0 0 12px; padding: 0; }
    li { padding: 5px 0; border-bottom: 1px solid #ddd; }
    .reply { margin: 10px 0; padding: 8px; background: #efe; border: 1px solid #cdc; }
    .note { margin: 8px 0; padding: 8px; background: #fdd; border: 1px solid #c99; }
    form { margin-top: 12px; }
    input { font-size: 15px; padding: 8px; width: 100%; box-sizing: border-box; }
    button { font-size: 15px; margin-top: 8px; padding: 8px 14px; }
  CSS
end
