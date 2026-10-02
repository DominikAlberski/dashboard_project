require "json"

module Agent
  # Llm calls ollama and cleans the model reply.
  class Llm
    CONNECT_LIMIT = 5
    REACHABLE_TIMEOUT = 2
    TIMEOUT_REPLY = "The model did not answer.".freeze
    THINK = /<think>.*?<\/think>/m

    def initialize(config, transport)
      @config = config
      @transport = transport
    end

    def chat(text)
      response = @transport.post(chat_url, body(text), chat_options)
      reply = clean(content(response))
      reply.empty? ? TIMEOUT_REPLY : reply
    rescue Transport::Error
      TIMEOUT_REPLY
    end

    def reachable?
      @transport.get(tags_url, probe_options)[:code] == 200
    rescue Transport::Error
      false
    end

    private

    def chat_options
      { timeout: @config.model_timeout, connect: CONNECT_LIMIT }
    end

    def probe_options
      { timeout: REACHABLE_TIMEOUT, connect: REACHABLE_TIMEOUT }
    end

    def body(text)
      JSON.generate("model" => @config.model_name, "stream" => false,
                    "messages" => [{ "role" => "user", "content" => text }])
    end

    def content(response)
      return "" unless response[:code].to_i == 200
      data = JSON.parse(response[:body].to_s)
      data.is_a?(Hash) ? data.dig("message", "content").to_s : ""
    rescue JSON::ParserError
      ""
    end

    def clean(text)
      text.to_s.gsub(THINK, "").strip
    end

    def chat_url
      "#{base_url}/api/chat"
    end

    def tags_url
      "#{base_url}/api/tags"
    end

    def base_url
      @config.model_host.sub(%r{/+\z}, "")
    end
  end
end
