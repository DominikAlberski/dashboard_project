require "io/console"

class Dashboard
  WAKE_INTERVAL = 1

  def initialize(api, screen, input)
    @api, @screen, @input = api, screen, input
    @queue = Queue.new
    build_parts
    @quit = false
  end

  def build_parts
    @view = ViewState.new
    @chat = ChatState.new
    @line = InputLine.new
    @poller = StatusPoller.new(@api, @queue)
  end

  def state
    @view.current
  end

  def run
    @poller.start
    @input.with_raw { tick until @quit }
  ensure
    @poller.stop
    @input.restore
  end

  def tick
    drain
    key = @input.read_key(WAKE_INTERVAL)
    handle_key(key) if key
    @view.set_status(@chat.text) if @chat.active?
    draw
  end

  def drain
    loop { @chat.finish if @view.apply(@queue.pop(true)) }
  rescue ThreadError
    nil
  end

  def pending_result?
    !@queue.empty?
  end

  def poll_status
    @poller.poll
  end

  def submit(text)
    return wait_for_chat if @chat.active?
    start_chat(text) unless text.to_s.empty?
  end

  def wait_for_chat
    @chat.wait
    @view.set_status(@chat.text)
  end

  def start_chat(text)
    @chat.start
    clear_input
    @view.mark_thinking
    @view.set_status(@chat.text)
    Thread.new { @queue << [:chat, reply_for(text)] }
  end

  def clear_input
    @line.clear
    @view.set_input("")
  end

  def reply_for(text)
    payload = @api.chat(text)
    payload["reply"] || payload["error"] || "no reply"
  rescue StandardError => e
    "error: #{e.class}"
  end

  def handle_key(key)
    event = @line.handle(key)
    return quit if event == :quit
    return submit(@line.text) if event == :submit
    @view.set_input(@line.text)
  end

  def quit
    @quit = true
  end

  def draw
    return unless @view.changed?
    @view.mark_rendered
    @screen.draw(@view.current)
  end
end

class ViewState
  attr_reader :current

  def initialize
    @current = empty
    @rendered = nil
    @device_label = "starting"
  end

  def apply(event)
    type, value = event
    type == :status ? apply_status(value) : apply_chat(value)
    type == :chat
  end

  def apply_status(payload)
    return set_status(error_text(payload)) if error?(payload)
    show_devices(payload["devices"] || [])
  end

  def error?(payload)
    payload.is_a?(Hash) && payload["error"]
  end

  def error_text(payload)
    "error: #{payload["error"]}"
  end

  def show_devices(devices)
    @device_label = label(devices)
    @current = @current.merge(:devices => devices, :status => @device_label)
  end

  def apply_chat(reply)
    @current = @current.merge(:reply => reply, :thinking => false,
                              :status => @device_label)
  end

  def mark_thinking
    @current = @current.merge(:thinking => true)
  end

  def set_input(text)
    @current = @current.merge(:input => text)
  end

  def set_status(text)
    @current = @current.merge(:status => text)
  end

  def changed?
    @current != @rendered
  end

  def mark_rendered
    @rendered = @current
  end

  def label(devices)
    return "1 device" if devices.size == 1
    "#{devices.size} devices"
  end

  def empty
    { :devices => [], :reply => "", :status => "starting",
      :input => "", :thinking => false }
  end
end

class ChatState
  def initialize
    @active = false
    @waiting = false
    @started_at = nil
  end

  def start
    @active = true
    @waiting = false
    @started_at = Time.now
  end

  def finish
    @active = false
    @waiting = false
  end

  def wait
    @waiting = true
  end

  def active?
    @active
  end

  def text
    return "waiting for reply" if @waiting
    "thinking #{seconds}s"
  end

  def seconds
    @started_at ? (Time.now - @started_at).to_i : 0
  end
end

class StatusPoller
  INTERVAL = 4

  def initialize(api, queue)
    @api = api
    @queue = queue
    @thread = nil
  end

  def start
    @thread = Thread.new { poll_forever }
  end

  def stop
    @thread.kill if @thread
  end

  def poll_forever
    loop do
      poll
      sleep INTERVAL
    end
  end

  def poll
    @queue << [:status, @api.status]
  rescue StandardError => e
    @queue << [:status, { "error" => e.class.to_s }]
  end
end

class InputLine
  attr_reader :text

  def initialize
    @text = ""
  end

  def handle(key)
    return :quit if quit?(key)
    return :submit if enter?(key)
    edit(key)
    nil
  end

  def clear
    @text = ""
  end

  def quit?(key)
    key == "\u0003" || (key == "q" && @text.empty?)
  end

  def enter?(key)
    key == "\r" || key == "\n"
  end

  def edit(key)
    return if backspace?(key) && remove
    append(key)
  end

  def backspace?(key)
    key == "\b" || key == "\u007F"
  end

  def remove
    return false if @text.empty?
    @text = @text[0...-1]
    true
  end

  def append(key)
    return unless printable?(key)
    @text += key
  end

  def printable?(key)
    key.ord >= 0x20 && key.ord != 0x7F
  end
end

class RawInput
  def initialize(io)
    @io = io
  end

  def with_raw
    @io.raw { yield }
  end

  def read_key(timeout)
    ready = IO.select([@io], nil, nil, timeout)
    return nil unless ready
    @io.getc
  end

  def restore
    @io.cooked! if @io.respond_to?(:cooked!)
  rescue IOError, SystemCallError
    nil
  end
end
