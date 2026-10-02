require "yaml"
require "ipaddr"

module Agent
  # Registry loads and validates devices.yml and finds a device by name.
  class Registry
    Error = Class.new(StandardError)

    NAME = /\A[a-z0-9][a-z0-9-]{0,31}\z/i
    MAC = /\A([0-9a-fA-F]{2}[:-]){5}[0-9a-fA-F]{2}\z/
    KEYS = [:name, :mac, :ip].freeze

    attr_reader :devices

    def self.load(path = "config/devices.yml")
      data = YAML.safe_load(File.read(path)) || {}
      new(data["devices"] || [])
    end

    def initialize(raw)
      @devices = raw.map { |device| normalize(device).freeze }.freeze
      validate!
      @by_name = @devices.each_with_object({}) { |device, map| map[device[:name].downcase] = device }
    end

    def find(name)
      return nil if name.nil?
      @by_name[name.downcase]
    end

    private

    def normalize(device)
      { name: device["name"].to_s, mac: mac_text(device["mac"]), ip: device["ip"].to_s }
    end

    def mac_text(value)
      value.to_s.upcase.tr("-", ":")
    end

    def validate!
      @devices.each_with_index { |device, index| validate_device(device, index) }
      validate_unique_names
    end

    def validate_device(device, index)
      raise Error, "device #{index}: name is invalid" unless device[:name].match?(NAME)
      raise Error, "device #{index}: mac is invalid" unless device[:mac].match?(MAC)
      raise Error, "device #{index}: ip is invalid" unless ip?(device[:ip])
    end

    def validate_unique_names
      names = @devices.map { |device| device[:name].downcase }
      raise Error, "device names must be unique" unless names.uniq.size == names.size
    end

    def ip?(value)
      IPAddr.new(value).ipv4?
    rescue IPAddr::InvalidAddressError
      false
    end
  end
end
