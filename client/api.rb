require "json"
require "net/http"

class Api
  OPEN_TIMEOUT = 3
  STATUS_READ = 5
  CHAT_READ = 180

  def initialize(base_url, http = Net::HTTP)
    @base_url = base_url.sub(%r{/+\z}, "")
    @http = http
  end

  def status
    request("GET", "/api/status", nil, STATUS_READ)
  end

  def chat(text)
    request("POST", "/api/chat", { "text" => text }, CHAT_READ)
  end

  def request(method, path, payload, read_timeout)
    uri = URI.parse(@base_url + path)
    response = transmit(uri, build(method, uri, payload), read_timeout)
    JSON.parse(response.body)
  end

  def transmit(uri, request, read_timeout)
    http = @http.new(uri.host, uri.port)
    http.open_timeout = OPEN_TIMEOUT
    http.read_timeout = read_timeout
    http.start { |session| session.request(request) }
  end

  def build(method, uri, payload)
    request = klass(method).new(uri.request_uri)
    request["Content-Type"] = "application/json" if payload
    set_body(request, payload)
  end

  def set_body(request, payload)
    request.body = JSON.generate(payload) if payload
    request
  end

  def klass(method)
    method == "POST" ? Net::HTTP::Post : Net::HTTP::Get
  end
end
