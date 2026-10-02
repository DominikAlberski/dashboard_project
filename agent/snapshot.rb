require "time"

module Agent
  # Snapshot owns the scan state. Only one scan runs at a time.
  class Snapshot
    def initialize(registry, scanner, config)
      @registry, @scanner, @config = registry, scanner, config
      @started_at = Time.now.utc.iso8601; @mutex = Mutex.new
      reset_state
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

    def reset_state
      @published = { devices: initial_devices, last_scan_at: nil }.freeze
      @scanning = false
      @last_scan_error = nil
    end

    def initial_devices
      @registry.devices.map { |device| entry({ ip: device[:ip], mac: device[:mac], online: false }, true, device[:name]) }
    end

    def entry(record, registered, name)
      record.merge(name: name, registered: registered).slice(:name, :ip, :mac, :online, :registered)
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
      state = { devices: merge_devices(records).freeze, last_scan_at: Time.now.utc.iso8601 }.freeze
      @mutex.synchronize { @published = state; @last_scan_error = nil; @scanning = false }
      state
    end

    def publish_error(message)
      @mutex.synchronize { @last_scan_error = message; @scanning = false }
    end

    def merge_devices(records)
      lookup = build_index(records); used = []
      registered = @registry.devices.map { |device| registered_entry(device, match(device, lookup), used) }
      registered + unregistered(records, used)
    end

    def registered_entry(device, record, used)
      used << record if record
      entry(record || { ip: device[:ip], mac: device[:mac], online: false }, true, device[:name])
    end

    def match(device, lookup)
      lookup[device[:mac].upcase] || lookup[device[:ip]]
    end

    def build_index(records)
      records.each_with_object({}) do |record, map|
        map[record[:mac].to_s.upcase] = record if record[:mac]; map[record[:ip]] = record
      end
    end

    def unregistered(records, used)
      records.select { |record| record[:online] && !used.include?(record) }
             .map { |record| entry(record, false, nil) }
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
