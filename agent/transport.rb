require "net/http"
require "timeout"
require "uri"

module Agent
  # Transport sends one HTTP request to the model host.
  class Transport
    Error = Class.new(StandardError)

    def post(url, body, timeout, connect_limit)
      send_request(:post, url, body, timeout, connect_limit)
    end

    def get(url, timeout, connect_limit)
      send_request(:get, url, nil, timeout, connect_limit)
    end

    private

    def send_request(method, url, body, timeout, connect_limit)
      uri = URI.parse(url)
      Timeout.timeout(timeout) { perform(method, uri, body, timeout, connect_limit) }
    rescue StandardError => error
      raise Error, error.message
    end

    def perform(method, uri, body, timeout, connect_limit)
      Net::HTTP.start(uri.host, uri.port, open_timeout: connect_limit, read_timeout: timeout) do |http|
        response = http.request(build_request(method, uri, body))
        { code: response.code.to_i, body: response.body.to_s }
      end
    end

    def build_request(method, uri, body)
      request = klass(method).new(uri.request_uri)
      return request unless body
      request["Content-Type"] = "application/json"
      request.body = body
      request
    end

    def klass(method)
      method == :post ? Net::HTTP::Post : Net::HTTP::Get
    end
  end
end
