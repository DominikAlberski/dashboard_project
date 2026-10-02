require_relative "api"
require_relative "screen"
require_relative "view_state"
require_relative "chat_state"
require_relative "status_poller"
require_relative "input_line"
require_relative "raw_input"

class Dashboard
  WAKE_INTERVAL = 1

  attr_reader :chat_thread

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
    stop_threads
    @input.restore
  end

  def stop_threads
    @poller.stop
    @chat_thread.kill if @chat_thread
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
    run_chat(text)
  end

  def clear_input
    @line.clear
    @view.set_input("")
  end

  def run_chat(text)
    @chat_thread = Thread.new { @queue << [:chat, reply_for(text)] }
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
