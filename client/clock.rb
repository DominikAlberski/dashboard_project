class Clock
  def monotonic
    Process.clock_gettime(Process::CLOCK_MONOTONIC)
  end

  def sleep(seconds)
    Kernel.sleep(seconds)
  end
end
