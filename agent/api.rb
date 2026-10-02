require "json"
require_relative "http_error"

module Agent
  # Api builds the JSON payload for each request path.
  class Api
    PATHS = { "/api/status" => "GET", "/api/chat" => "POST", "/api/action" => "POST" }.freeze

    def initialize(services)
      @config = services.fetch(:config)
      @snapshot = services.fetch(:snapshot)
      @monitor = services.fetch(:monitor)
      @chat = services.fetch(:chat)
    end

    def call(request)
      path = request[:path]
      raise HttpError.new(404, "not found") unless PATHS.key?(path)
      raise HttpError.new(405, "method not allowed") unless PATHS[path] == request[:method]
      dispatch(path, request[:body])
    end

    private

    def dispatch(path, body)
      case path
      when "/api/status" then [200, status_payload]
      when "/api/chat" then [200, chat_payload(body)]
      when "/api/action" then [200, action_payload(body)]
      end
    end

    def status_payload
      status = @snapshot.status
      { "devices" => status[:devices], "agent" => status[:agent], "model" => model_payload }
    end

    def model_payload
      { "host" => @config.model_host, "name" => @config.model_name, "reachable" => @monitor.reachable }
    end

    def chat_payload(body)
      data = parse_object(body)
      text = data["text"]
      validate_text(text)
      result = @chat.reply(text)
      { "reply" => result[:reply], "action" => result[:action] }
    end

    def validate_text(text)
      raise HttpError.new(422, "text is required") unless text.is_a?(String)
      raise HttpError.new(422, "text is empty") if text.strip.empty?
      raise HttpError.new(422, "text is too long") if text.strip.length > 1000
    end

    def action_payload(body)
      data = parse_object(body)
      action = action_field(data)
      { "result" => @chat.perform(action, data["target"]) }
    rescue Chat::Error => error
      raise HttpError.new(422, error.message)
    end

    def action_field(data)
      action = data["action"]
      raise HttpError.new(422, "action is required") unless action.is_a?(String)
      action
    end

    def parse_object(body)
      data = JSON.parse(body.to_s)
      raise HttpError.new(400, "body must be an object") unless data.is_a?(Hash)
      data
    rescue JSON::ParserError
      raise HttpError.new(400, "body must be valid JSON")
    end
  end
end
