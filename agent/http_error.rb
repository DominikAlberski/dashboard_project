module Agent
  # HttpError carries the response status code for one failed request.
  class HttpError < StandardError
    attr_reader :code

    def initialize(code, message)
      @code = code
      super(message)
    end
  end
end
