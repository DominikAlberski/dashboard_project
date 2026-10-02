require_relative "http_error"

module Agent
  # HttpRequest reads and parses one HTTP/1.1 request from a socket.
  class HttpRequest
    HEADER_LIMIT = 8192
    BODY_LIMIT = 16 * 1024
    READ_TIMEOUT = 5
    VERSION = %r{\AHTTP/1\.[01]\z}

    def self.read(socket, timeout = READ_TIMEOUT)
      new(socket, timeout).read
    end

    def initialize(socket, timeout)
      @socket = socket
      @timeout = timeout
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
      @buffer << next_chunk until head_done?
    end

    def head_done?
      boundary = header_boundary
      return true if boundary && boundary <= HEADER_LIMIT
      raise HttpError.new(413, "headers too large") if boundary || @buffer.bytesize > HEADER_LIMIT
      false
    end

    def header_boundary
      match = @buffer.match(/\r?\n\r?\n/)
      match && match.end(0)
    end

    def request_line(head)
      method, path, version = head.split(/\r?\n/).first.to_s.split(" ")
      raise HttpError.new(400, "bad request line") unless method && path && version
      raise HttpError.new(400, "unsupported version") unless version.match?(VERSION)
      [method.upcase, path]
    end

    def body_for(rest, method, head)
      return "" unless method == "POST"
      length = content_length(head)
      validate_length(length)
      @deadline = monotonic + @timeout
      read_body(rest, length)
    end

    def validate_length(length)
      raise HttpError.new(411, "content length required") if length.nil?
      raise HttpError.new(413, "body too large") if length > BODY_LIMIT
    end

    def content_length(head)
      lines = head.split(/\r?\n/)
      reject_transfer_encoding(lines)
      validate_content_lengths(content_length_values(lines))
    end

    def content_length_values(lines)
      fields = lines.select { |line| line.match?(/\AContent-Length:/i) }
      fields.map { |line| line.split(":", 2)[1].to_s.strip }
    end

    def validate_content_lengths(values)
      return nil if values.empty?
      raise HttpError.new(400, "bad content length") unless values.all? { |value| value.match?(/\A\d+\z/) }
      raise HttpError.new(400, "conflicting content length") unless values.uniq.size == 1
      values.first.to_i
    end

    def reject_transfer_encoding(lines)
      return unless lines.any? { |line| line.match?(/\ATransfer-Encoding:/i) }
      raise HttpError.new(400, "transfer encoding is not supported")
    end

    def read_body(rest, length)
      body = rest.dup
      body << next_chunk while body.bytesize < length
      body[0, length]
    end

    def next_chunk
      chunk = read_chunk
      raise HttpError.new(400, "bad request") if chunk.nil?
      chunk
    end

    def read_chunk
      loop do
        wait_readable
        chunk = @socket.read_nonblock(4096, exception: false)
        return chunk unless chunk == :wait_readable
      end
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
