require "json"
require "socket"
require_relative "api"
require_relative "http_error"
require_relative "http_request"

module Agent
  # Server serves the JSON API over one HTTP/1.1 connection per request.
  class Server
    REASONS = {
      200 => "OK", 400 => "Bad Request", 404 => "Not Found", 405 => "Method Not Allowed",
      408 => "Request Timeout", 411 => "Length Required", 413 => "Payload Too Large",
      422 => "Unprocessable Entity", 500 => "Internal Server Error"
    }.freeze

    def initialize(services, port: nil, read_timeout: HttpRequest::READ_TIMEOUT)
      @config = services.fetch(:config)
      @api = Api.new(services)
      @port = port || @config.port
      @read_timeout = read_timeout
    end

    def start
      @server = TCPServer.new(@config.bind, @port)
      @thread = Thread.new { accept_loop }
      self
    end

    def port
      @server.addr[1]
    end

    def stop
      @server&.close
      @thread&.kill
    end

    private

    def accept_loop
      loop { spawn(@server.accept) }
    rescue IOError, Errno::EBADF
      nil
    end

    def spawn(client)
      Thread.new { handle(client) }
    end

    def handle(socket)
      respond(socket, HttpRequest.read(socket, @read_timeout))
    rescue StandardError => error
      write_failure(socket, error)
    ensure
      close(socket)
    end

    def respond(socket, request)
      code, payload = @api.call(request)
      write_response(socket, code, payload)
    end

    def write_failure(socket, error)
      write_response(socket, error_code(error), { "error" => error.message })
    end

    def error_code(error)
      error.is_a?(HttpError) ? error.code : 500
    end

    def close(socket)
      socket.close unless socket.closed?
    rescue IOError, Errno::EBADF
      nil
    end

    def write_response(socket, code, payload)
      body = JSON.generate(payload)
      socket.write(head(code, body) + body)
    end

    def head(code, body)
      "HTTP/1.1 #{code} #{REASONS.fetch(code, "OK")}\r\n" \
        "Content-Type: application/json\r\n" \
        "Content-Length: #{body.bytesize}\r\n" \
        "Connection: close\r\n\r\n"
    end
  end
end
