require "timeout"

module Agent
  # Runner runs one subprocess from an argument array with a deadline.
  # If the deadline passes, Runner kills the process and returns a failure.
  class Runner
    def run(argv, timeout)
      io = IO.popen(argv, err: [:child, :out])
      output = read_with_deadline(io, timeout)
      output ? success(io, output) : failure(io)
    end

    private

    def read_with_deadline(io, timeout)
      Timeout.timeout(timeout) { io.read }
    rescue Timeout::Error
      nil
    end

    def success(io, output)
      io.close
      { success: $?.success?, output: output }
    end

    def failure(io)
      kill(io)
      io.close
      { success: false, output: "" }
    end

    def kill(io)
      Process.kill("KILL", io.pid)
    rescue Errno::ESRCH
      nil
    end
  end
end
