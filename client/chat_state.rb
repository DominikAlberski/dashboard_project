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
