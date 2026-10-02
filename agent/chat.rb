require "ipaddr"

module Agent
  # Chat routes text to a device action or to the model.
  class Chat
    Error = Class.new(StandardError)
    COMMANDS = %w[ping scan wake ports].freeze
    IPV4 = /\A(\d{1,3})\.(\d{1,3})\.(\d{1,3})\.(\d{1,3})\z/

    def initialize(services)
      @services = services
    end

    def reply(text)
      word, rest = split(text)
      return model_reply(text) unless COMMANDS.include?(word)
      { reply: perform(word, rest), action: word }
    rescue Error => error
      { reply: error.message, action: "unknown_target" }
    end

    def perform(action, target)
      raise Error, "unknown action: #{action}" unless COMMANDS.include?(action)
      dispatch(action, target)
    end

    private

    def dispatch(action, target)
      return scan if action == "scan"
      return wake(target) if action == "wake"
      return ports(target) if action == "ports"
      ping(target)
    end

    def ping(target)
      ip = address(target)
      scanner.ping(ip) ? "#{ip} is up" : "#{ip} is down"
    end

    def scan
      snapshot.scan_now
      "scan complete"
    end

    def wake(target)
      device = named_device(target)
      wol.wake(device[:mac])
      "sent magic packet to #{device[:name]}"
    end

    def ports(target)
      open = scanner.check_ports(address(target))
      open.empty? ? "no open ports" : "open ports: #{open.join(", ")}"
    end

    def model_reply(text)
      { reply: llm.chat(text), action: "model" }
    end

    def address(target)
      return target if in_range?(target)
      device = registry.find(target)
      raise Error, unknown_message(target) if device.nil?
      device[:ip]
    end

    def named_device(target)
      device = registry.find(target)
      raise Error, "wake needs a device name. devices: #{names}" if device.nil?
      device
    end

    def in_range?(target)
      return false unless target && target.match?(IPV4)
      IPAddr.new(config.scan_range).include?(target)
    rescue IPAddr::InvalidAddressError
      false
    end

    def unknown_message(target)
      "unknown target #{target}. devices: #{names}"
    end

    def names
      registry.devices.map { |device| device[:name] }.join(", ")
    end

    def split(text)
      parts = text.to_s.strip.split(/\s+/, 2)
      [parts[0].to_s.downcase, parts[1].to_s.strip]
    end

    def config
      @services.fetch(:config)
    end

    def registry
      @services.fetch(:registry)
    end

    def scanner
      @services.fetch(:scanner)
    end

    def snapshot
      @services.fetch(:snapshot)
    end

    def wol
      @services.fetch(:wol)
    end

    def llm
      @services.fetch(:llm)
    end
  end
end
