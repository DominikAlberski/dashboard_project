require "net/http"
require "timeout"
require "uri"

module Agent
  # Transport sends one HTTP request to the model host.
  class Transport
    Error = Class.new(StandardError)

    def initialize(http = Net::HTTP)
      @http = http
    end

    def post(url, body, options)
      send_request(:post, url, body, options)
    end

    def get(url, options)
      send_request(:get, url, nil, options)
    end

    private

    def send_request(method, url, body, options)
      uri = URI.parse(url)
      Timeout.timeout(options.fetch(:timeout)) { perform(method, uri, body, options) }
    rescue StandardError => error
      raise Error, error.message
    end

    def perform(method, uri, body, options)
      @http.start(uri.host, uri.port, **timeout_options(options)) do |http|
        response = http.request(build_request(method, uri, body))
        { code: response.code.to_i, body: response.body.to_s }
      end
    end

    def timeout_options(options)
      { open_timeout: options.fetch(:connect), read_timeout: options.fetch(:timeout) }
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
