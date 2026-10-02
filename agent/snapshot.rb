require "time"

require_relative "device_merge"

module Agent
  # Snapshot owns the scan state. Only one scan runs at a time.
  class Snapshot
    def initialize(registry, scanner, config)
      @merge = DeviceMerge.new(registry)
      @scanner, @config = scanner, config
      setup_state
    end

    def scan_now
      await_worker
      status
    end

    def status
      @mutex.synchronize do
        { devices: @published[:devices], agent: agent_status }.freeze
      end
    end

    def agent_status
      { started_at: @started_at, last_scan_at: @published[:last_scan_at],
        scanning: @scanning, last_scan_error: @last_scan_error }.freeze
    end

    def start
      @running = true
      @background = Thread.new { background_loop }
    end

    def stop
      @running = false
      @background&.kill
    end

    private

    def setup_state
      @mutex = Mutex.new
      @started_at = Time.now.utc.iso8601
      setup_published
    end

    def setup_published
      @published = { devices: @merge.offline_devices.freeze, last_scan_at: nil }.freeze
      @scanning = false
      @last_scan_error = nil
    end

    def worker_thread
      @mutex.synchronize { @worker ||= Thread.new { run_scan } }
    end

    def await_worker
      thread = worker_thread
      thread.value
      clear_worker(thread)
    end

    def clear_worker(thread)
      @mutex.synchronize { @worker = nil if @worker == thread }
    end

    def run_scan
      @mutex.synchronize { @scanning = true }
      scan_safely
    end

    def scan_safely
      publish(@scanner.scan)
    rescue StandardError => error
      publish_error(error.message)
    end

    def publish(records)
      state = { devices: @merge.merge(records).freeze, last_scan_at: Time.now.utc.iso8601 }.freeze
      store_state(state)
      state
    end

    def store_state(state)
      @mutex.synchronize { apply_state(state) }
    end

    def apply_state(state)
      @published = state
      @last_scan_error = nil
      @scanning = false
    end

    def publish_error(message)
      @mutex.synchronize { apply_error(message) }
    end

    def apply_error(message)
      @last_scan_error = message
      @scanning = false
    end

    def background_loop
      while @running
        tick
      end
    end

    def tick
      sleep @config.scan_interval
      scan_now if @running
    end
  end
end
