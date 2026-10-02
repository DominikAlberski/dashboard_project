require_relative "http_error"

module Agent
  # HttpRequest reads and parses one HTTP/1.1 request from a socket.
  class HttpRequest
    HEADER_LIMIT = 8192
    BODY_LIMIT = 16 * 1024
    READ_TIMEOUT = 5

    def self.read(socket, timeout = READ_TIMEOUT)
      new(socket, timeout).read
    end

    def initialize(socket, timeout)
      @socket = socket
      @deadline = monotonic + timeout
      @buffer = +""
    end

    def read
      fill_head
      head, rest = @buffer.split(/\r?\n\r?\n/, 2)
      method, path = request_line(head.to_s)
      { method: method, path: path, body: body_for(rest.to_s, method, head.to_s) }
    end

    private

    def fill_head
      return if @buffer.match?(/\r?\n\r?\n/)
      raise HttpError.new(413, "headers too large") if @buffer.bytesize > HEADER_LIMIT
      @buffer << next_chunk
      fill_head
    end

    def request_line(head)
      method, path, = head.split(/\r?\n/).first.to_s.split(" ")
      [method.to_s.upcase, path.to_s]
    end

    def body_for(rest, method, head)
      return "" unless method == "POST"
      length = content_length(head)
      raise HttpError.new(411, "content length required") if length.nil?
      raise HttpError.new(413, "body too large") if length > BODY_LIMIT
      read_body(rest, length)
    end

    def content_length(head)
      line = head.split(/\r?\n/).find { |item| item.downcase.start_with?("content-length:") }
      line && line.split(":", 2)[1].to_s.strip.to_i
    end

    def read_body(rest, length)
      body = rest.dup
      body << next_chunk while body.bytesize < length
      body[0, length]
    end

    def next_chunk
      wait_readable
      chunk = @socket.read_nonblock(4096, exception: false)
      raise HttpError.new(400, "bad request") if chunk.nil?
      chunk == :wait_readable ? next_chunk : chunk
    end

    def wait_readable
      remaining = @deadline - monotonic
      raise HttpError.new(408, "read deadline") if remaining <= 0
      raise HttpError.new(408, "read deadline") unless IO.select([@socket], nil, nil, remaining)
    end

    def monotonic
      Process.clock_gettime(Process::CLOCK_MONOTONIC)
    end
  end
end
