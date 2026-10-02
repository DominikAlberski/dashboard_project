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
      response = @transport.post(chat_url, body(text), @config.model_timeout, CONNECT_LIMIT)
      clean(content(response))
    rescue Transport::Error
      TIMEOUT_REPLY
    end

    def reachable?
      @transport.get(tags_url, REACHABLE_TIMEOUT, REACHABLE_TIMEOUT)[:code] == 200
    rescue Transport::Error
      false
    end

    private

    def body(text)
      JSON.generate("model" => @config.model_name, "stream" => false,
                    "messages" => [{ "role" => "user", "content" => text }])
    end

    def content(response)
      JSON.parse(response[:body].to_s).dig("message", "content").to_s
    rescue JSON::ParserError
      ""
    end

    def clean(text)
      text.to_s.gsub(THINK, "").strip
    end

    def chat_url
      "#{@config.model_host}/api/chat"
    end

    def tags_url
      "#{@config.model_host}/api/tags"
    end
  end
end
