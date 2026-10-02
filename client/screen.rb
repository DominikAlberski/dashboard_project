require_relative "sanitizer"

class Screen
  CLEAR = "\e[2J\e[H".freeze

  def initialize(io)
    @io = io
  end

  def draw(state)
    @io.print(CLEAR + render(state))
    @io.flush if @io.respond_to?(:flush)
  end

  def render(state)
    lines = [status_line(state)]
    lines.concat(device_lines(state[:devices]))
    lines << reply_line(state[:reply])
    lines << prompt_line(state)
    lines.join("\n")
  end

  def status_line(state)
    Sanitizer.clean(state[:status].to_s)
  end

  def device_lines(devices)
    return ["(no devices)"] if devices.nil? || devices.empty?
    devices.map { |device| device_line(device) }
  end

  def device_line(device)
    mark = device["online"] ? "*" : " "
    "#{mark} #{device_name(device)} #{Sanitizer.clean(device["ip"].to_s)}"
  end

  def device_name(device)
    value = device["registered"] ? device["name"] : device["ip"]
    Sanitizer.clean(value.to_s)
  end

  def reply_line(reply)
    "reply: #{Sanitizer.clean(reply)}"
  end

  def prompt_line(state)
    "> #{Sanitizer.clean(state[:input].to_s)}"
  end
end
