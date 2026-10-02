require "minitest/autorun"

require_relative "../../agent/config"
require_relative "../../agent/registry"
require_relative "../../agent/runner"
require_relative "../../agent/scanner"
require_relative "../../agent/device_merge"
require_relative "../../agent/snapshot"
require_relative "../../agent/wol"

module AgentTest
  ROOT = File.expand_path("../..", __dir__)

  class FakeRunner
    attr_reader :calls

    def initialize(results = {})
      @results = results
      @calls = []
    end

    def run(argv, timeout)
      @calls << { argv: argv, timeout: timeout }
      @results.fetch(argv.first, { success: true, output: "" })
    end
  end

  class FakeConnector
    def initialize(open_ports)
      @open_ports = open_ports
    end

    def call(_ip, port, _timeout)
      @open_ports.include?(port)
    end
  end

  class FakeSocket
    attr_reader :sent

    def initialize
      @sent = []
    end

    def send(data, flags, host, port)
      @sent << { data: data, flags: flags, host: host, port: port }
      0
    end
  end
end
