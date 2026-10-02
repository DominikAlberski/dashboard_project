require "timeout"

module Agent
  # Runner runs one subprocess from an argument array with a deadline.
  # If the deadline passes, Runner kills the process and returns a failure.
  class Runner
    def run(argv, timeout)
      io = IO.popen(argv, err: [:child, :out])
      capture(io, timeout)
    end

    private

    def capture(io, timeout)
      output, success = Timeout.timeout(timeout) { collect(io) }
      { success: success, output: output }
    rescue Timeout::Error
      terminate(io)
    end

    def collect(io)
      output = io.read
      io.close
      [output, $?.success?]
    end

    def terminate(io)
      kill(io)
      reap(io)
      { success: false, output: "" }
    end

    def kill(io)
      Process.kill("KILL", io.pid)
    rescue Errno::ESRCH
      nil
    end

    def reap(io)
      Process.wait(io.pid)
    rescue Errno::ECHILD
      nil
    ensure
      close_io(io)
    end

    def close_io(io)
      io.close unless io.closed?
    rescue IOError, Errno::ECHILD
      nil
    end
  end
end
