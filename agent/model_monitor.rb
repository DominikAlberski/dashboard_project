module Agent
  # ModelMonitor owns the cached model reachability.
  class ModelMonitor
    INTERVAL = 30

    def initialize(llm, interval = INTERVAL)
      @llm = llm
      @interval = interval
      @reachable = nil
      @mutex = Mutex.new
    end

    def reachable
      @mutex.synchronize { @reachable }
    end

    def check
      value = @llm.reachable?
      @mutex.synchronize { @reachable = value }
    end

    def start
      @running = true
      @thread = Thread.new { loop_check }
    end

    def stop
      @running = false
      @thread&.kill
    end

    private

    def loop_check
      while @running
        check
        sleep @interval
      end
    end
  end
end
