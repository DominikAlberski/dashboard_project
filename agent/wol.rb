require "socket"

module Agent
  # Wol builds the Wake-on-LAN magic packet and sends it over UDP broadcast.
  class Wol
    BROADCAST = "255.255.255.255".freeze
    PORT = 9
    USAGE = "usage: bin/wol <name or MAC>".freeze
    MAC_PATTERN = /\A([0-9a-fA-F]{2}[:-]){5}[0-9a-fA-F]{2}\z/

    def self.run(argv, registry:, socket: nil)
      mac = resolve(argv[0], registry)
      return [2, USAGE] unless mac
      deliver(mac, socket)
    end

    def self.deliver(mac, socket)
      new(socket).wake(mac)
      [0, "sent magic packet to #{mac}"]
    rescue StandardError => error
      [1, error.message]
    end

    def self.resolve(argument, registry)
      return nil if argument.nil? || argument.empty?
      return argument if argument.match?(MAC_PATTERN)
      device = registry.find(argument)
      device && device[:mac]
    end

    def initialize(socket = nil)
      @socket = socket
    end

    def packet(mac)
      ("\xFF".b * 6) + (mac_bytes(mac) * 16)
    end

    def wake(mac)
      socket = @socket || broadcast_socket
      socket.send(packet(mac), 0, BROADCAST, PORT)
    ensure
      socket.close if @socket.nil? && socket && !socket.closed?
    end

    private

    def mac_bytes(mac)
      hex = mac.to_s.tr("-", ":").delete(":")
      raise ArgumentError, "invalid MAC address" unless hex.match?(/\A[0-9a-fA-F]{12}\z/)
      [hex].pack("H*")
    end

    def broadcast_socket
      socket = UDPSocket.new
      socket.setsockopt(Socket::SOL_SOCKET, Socket::SO_BROADCAST, true)
      socket
    end
  end
end
