require "io/console"

class Dashboard
  POLL_INTERVAL = 4

  attr_reader :state

  def initialize(api, screen, input)
    @api, @screen, @input = api, screen, input
    @queue, @chatting, @quit = Queue.new, false, false
    @line = InputLine.new
    @state = empty_state
  end

  def run
    @input.with_raw do
      tick until @quit
    end
  ensure
    @input.restore
  end

  def tick
    drain
    poll
    key = @input.read_key(POLL_INTERVAL)
    handle_key(key) if key
    draw
  end

  def drain
    loop { apply(@queue.pop(true)) }
  rescue ThreadError
    nil
  end

  def apply(reply)
    @state = @state.merge(:reply => reply, :thinking => false)
    @chatting = false
  end

  def poll
    update(@api.status)
  rescue StandardError => e
    @state = @state.merge(:status => "error: #{e.class}")
  end

  def update(status)
    devices = status["devices"] || []
    @state = @state.merge(:devices => devices, :status => label(devices))
  end

  def label(devices)
    "#{devices.size} devices"
  end

  def submit(text)
    return if @chatting || text.to_s.empty?
    start_chat(text)
  end

  def start_chat(text)
    @chatting = true
    @line.clear
    @state = @state.merge(:thinking => true, :input => "")
    Thread.new { @queue << reply_for(text) }
  end

  def reply_for(text)
    @api.chat(text)["reply"]
  rescue StandardError => e
    "error: #{e.class}"
  end

  def pending_result?
    !@queue.empty?
  end

  def handle_key(key)
    event = @line.handle(key)
    return quit if event == :quit
    return submit(@line.text) if event == :submit
    @state = @state.merge(:input => @line.text)
  end

  def quit
    @quit = true
  end

  def draw
    @screen.draw(@state)
  end

  def empty_state
    { :devices => [], :reply => "", :status => "starting",
      :input => "", :thinking => false }
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
