require "minitest/autorun"

require_relative "../../agent/config"
require_relative "../../agent/registry"
require_relative "../../agent/runner"
require_relative "../../agent/scanner"
require_relative "../../agent/device_merge"
require_relative "../../agent/snapshot"
require_relative "../../agent/wol"
require_relative "../../agent/transport"
require_relative "../../agent/llm"
require_relative "../../agent/model_monitor"
require_relative "../../agent/chat"
require_relative "../../agent/server"

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
      @closed = false
    end

    def send(data, flags, host, port)
      @sent << { data: data, flags: flags, host: host, port: port }
      0
    end

    def close
      @closed = true
    end

    def closed?
      @closed
    end
  end

  class BehaviorScanner
    attr_reader :calls

    def initialize(&block)
      @block = block
      @calls = 0
    end

    def scan
      @calls += 1
      @block.call
    end
  end

  class FakeLlm
    attr_reader :checks, :messages

    def initialize(reachable: true, reply: "model reply", queue: nil)
      @reachable = reachable
      @reply = reply
      @queue = queue
      @checks = 0
      @messages = []
    end

    def reachable?
      @checks += 1
      @queue << true if @queue
      @reachable
    end

    def chat(text)
      @messages << text
      @reply
    end
  end

  class StubSnapshot
    def initialize(devices: [])
      @devices = devices
    end

    def status
      { devices: @devices,
        agent: { started_at: "t", last_scan_at: nil, scanning: false, last_scan_error: nil } }
    end

    def scan_now
      status
    end
  end

  class StubMonitor
    def initialize(reachable = nil)
      @reachable = reachable
    end

    def reachable
      @reachable
    end
  end

  class StubChat
    def initialize(&block)
      @block = block
    end

    def reply(text)
      @block ? @block.call(text) : { reply: "ok", action: "model" }
    end

    def perform(action, target)
      raise Agent::Chat::Error, "unknown action: #{action}" unless %w[ping scan wake ports].include?(action)
      "done #{action} #{target}"
    end
  end

  def self.device_registry
    Agent::Registry.new(
      [
        { "name" => "pc", "mac" => "AA:BB:CC:DD:EE:01", "ip" => "192.168.33.10" },
        { "name" => "nas", "mac" => "AA:BB:CC:DD:EE:02", "ip" => "192.168.33.11" }
      ]
    )
  end
end
