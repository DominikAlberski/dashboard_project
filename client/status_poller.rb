require_relative "clock"

class StatusPoller
  INTERVAL = 4

  def initialize(api, queue, clock = Clock.new)
    @api = api
    @queue = queue
    @clock = clock
    @thread = nil
  end

  def start
    @thread = Thread.new { poll_forever }
  end

  def stop
    @thread.kill if @thread
  end

  def poll_forever
    loop { wait_for_next }
  end

  def wait_for_next
    started = @clock.monotonic
    poll
    remaining = INTERVAL - (@clock.monotonic - started)
    @clock.sleep(remaining) if remaining > 0
  end

  def poll
    @queue << [:status, checked(@api.status)]
  rescue StandardError => e
    @queue << [:status, { "error" => e.class.to_s }]
  end

  def checked(status)
    return { "error" => "invalid status" } unless valid?(status)
    status
  end

  def valid?(status)
    return true if error?(status)
    return false unless status.is_a?(Hash)
    valid_devices?(status["devices"])
  end

  def error?(status)
    status.is_a?(Hash) && status["error"]
  end

  def valid_devices?(devices)
    return false unless devices.is_a?(Array)
    devices.all? { |device| device.is_a?(Hash) }
  end
end
