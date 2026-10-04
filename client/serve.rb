require "socket"
require "uri"
require_relative "page"

# Serve runs the dashboard as an HTML page on the 3GS. It polls the agent
# over the LAN for status, and posts chat back to the agent.
class Serve
  READ_TIMEOUT = 5
  MAX_BODY = 4096

  def initialize(api, port:, bind: "127.0.0.1")
    @api = api
    @server = TCPServer.new(bind, port)
    @reply = nil
  end

  def port
    @server.addr[1]
  end

  def run
    loop { serve_one }
  rescue IOError, Errno::EBADF
    nil
  end

  def stop
    @server.close unless @server.closed?
  end

  private

  def serve_one
    client = @server.accept
    Thread.new { handle(client) }
  end

  def handle(client)
    request = read_request(client)
    client.write(response(request))
  rescue StandardError => error
    warn("request failed: #{error.class}: #{error.message}")
  ensure
    client.close unless client.closed?
  end

  def read_request(client)
    client.timeout = READ_TIMEOUT
    line = client.gets
    return { method: "GET", path: "/", body: "" } if line.nil?
    method, path = request_line(line)
    headers = read_headers(client)
    body = method == "POST" ? read_body(client, headers) : ""
    { method: method, path: path, body: body }
  end

  def request_line(line)
    method, path, = line.split(" ")
    [method.to_s.upcase, path.to_s]
  end

  def read_headers(client)
    headers = {}
    loop do
      line = client.gets
      break if line.nil? || line.strip.empty?
      key, value = line.split(":", 2)
      headers[key.to_s.downcase] = value.to_s.strip if key && value
    end
    headers
  end

  def read_body(client, headers)
    length = headers.fetch("content-length", "0").to_i
    return "" if length <= 0 || length > MAX_BODY
    client.read(length).to_s
  end

  def response(request)
    body = request[:method] == "POST" ? chat_page(request) : status_page
    http(body)
  end

  def status_page
    snapshot = status
    Page.new(devices: snapshot.fetch("devices", []), reply: @reply,
             model: snapshot.fetch("model", {})).to_html
  end

  def chat_page(request)
    text = form_text(request[:body])
    @reply = text.empty? ? nil : reply_for(text)
    status_page
  end

  def form_text(body)
    URI.decode_www_form(body).to_h["text"].to_s
  rescue ArgumentError
    ""
  end

  def reply_for(text)
    @api.chat(text)["reply"]
  rescue StandardError => error
    "error: #{error.class}"
  end

  def status
    @api.status
  rescue StandardError
    { "devices" => [], "model" => {} }
  end

  def http(body)
    ["HTTP/1.1 200 OK", "Content-Type: text/html; charset=utf-8",
     "Content-Length: #{body.bytesize}", "Cache-Control: no-store",
     "Connection: close", "", body].join("\r\n")
  end
end
