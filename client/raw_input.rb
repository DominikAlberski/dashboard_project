require "io/console"

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
