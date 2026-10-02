require "yaml"
require "uri"

module Agent
  # Config loads config/agent.yml, applies the defaults, and validates each value.
  class Config
    Error = Class.new(StandardError)
    IPV4 = /\A(\d{1,3})\.(\d{1,3})\.(\d{1,3})\.(\d{1,3})\z/

    DEFAULTS = {
      "bind" => "0.0.0.0",
      "port" => 4567,
      "scan_range" => "192.168.33.0/24",
      "scan_interval" => 30,
      "ping_timeout" => 1,
      "ports" => [22, 80, 443, 445, 3389, 5900, 11_434].freeze,
      "model_host" => "http://192.168.33.34:11434",
      "model_name" => "qwen3.8-ridge-16k:latest",
      "model_timeout" => 170,
      "devices_file" => "config/devices.yml"
    }.freeze

    CHECKS = [
      ["bind", "a plain IPv4 address", ->(value) { ipv4?(value) }],
      ["port", "an integer from 1 to 65535", ->(value) { int?(value, 1, 65_535) }],
      ["scan_range", "an IPv4 CIDR with prefix 24 to 30", ->(value) { cidr?(value) }],
      ["scan_interval", "an integer of 5 or more", ->(value) { int?(value, 5, nil) }],
      ["ping_timeout", "an integer from 1 to 5", ->(value) { int?(value, 1, 5) }],
      ["ports", "an array of integers from 1 to 65535", ->(value) { ports?(value) }],
      ["model_host", "an http URL with a host", ->(value) { http_url?(value) }],
      ["model_name", "a nonempty string", ->(value) { nonempty?(value) }],
      ["model_timeout", "an integer from 10 to 170", ->(value) { int?(value, 10, 170) }],
      ["devices_file", "a nonempty path", ->(value) { nonempty?(value) }]
    ].freeze

    attr_reader :values

    def self.load(path = "config/agent.yml")
      new(YAML.safe_load(File.read(path)) || {})
    end

    def initialize(values = {})
      @values = build_values(values)
      validate!
      freeze_values
    end

    def [](key)
      @values[key]
    end

    DEFAULTS.each_key { |key| define_method(key) { @values[key] } }

    def validate!
      CHECKS.each do |key, rule, check|
        raise Error, "#{key} must be #{rule}" unless check.call(@values[key])
      end
    end

    def self.int?(value, minimum, maximum)
      value.is_a?(Integer) && value >= minimum && (maximum.nil? || value <= maximum)
    end

    def self.nonempty?(value)
      value.is_a?(String) && !value.strip.empty?
    end

    def self.ipv4?(value)
      match = value.to_s.match(IPV4)
      match && match.captures.all? { |part| part.to_i <= 255 }
    end

    def self.cidr?(value)
      match = value.to_s.match(/\A(\d+\.\d+\.\d+\.\d+)\/(\d+)\z/)
      match && ipv4?(match[1]) && int?(match[2].to_i, 24, 30)
    end

    def self.http_url?(value)
      uri = URI.parse(value.to_s)
      uri.scheme == "http" && !uri.host.to_s.empty? && valid_port?(uri)
    rescue URI::InvalidURIError
      false
    end

    def self.valid_port?(uri)
      uri.port.between?(1, 65_535)
    end

    def self.ports?(value)
      value.is_a?(Array) && value.all? { |port| int?(port, 1, 65_535) }
    end

    private

    def build_values(values)
      merged = DEFAULTS.merge(values)
      merged.transform_values { |value| duplicate(value) }
    end

    def duplicate(value)
      value.is_a?(String) || value.is_a?(Array) ? value.dup : value
    end

    def freeze_values
      @values.each_value { |value| value.freeze unless value.frozen? }
      @values.freeze
    end
  end
end
