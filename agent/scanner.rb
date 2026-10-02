require "ipaddr"
require "socket"

module Agent
  # Scanner runs one scan. It pings each address in the range, reads the ARP
  # table, and checks the TCP ports of one address.
  class Scanner
    Error = Class.new(StandardError)
    PING_POOL = 32
    ARP_TIMEOUT = 2
    PORT_TIMEOUT = 1

    DEFAULT_CONNECTOR = lambda do |ip, port, timeout|
      socket = Socket.tcp(ip, port, connect_timeout: timeout)
      socket.close
      true
    rescue StandardError
      false
    end

    def initialize(config, runner, connector = DEFAULT_CONNECTOR)
      @config = config
      @runner = runner
      @connector = connector
    end

    def scan
      addresses = addresses_in_range
      reachable = ping_all(addresses)
      build_records(addresses, reachable, arp_table)
    end

    def check_ports(ip)
      threads = @config.ports.map { |port| port_thread(ip, port) }
      threads.map(&:value).compact.sort
    end

    private

    def addresses_in_range
      addresses = IPAddr.new(@config.scan_range).to_range.to_a.map(&:to_s)
      addresses[1..-2] || addresses
    end

    def ping_all(addresses)
      queue = Queue.new
      addresses.each { |ip| queue << ip }
      results = {}
      run_workers(queue, results)
      results
    end

    def run_workers(queue, results)
      count = [PING_POOL, queue.size].min
      workers = Array.new(count) { Thread.new { ping_worker(queue, results) } }
      workers.each(&:join)
    end

    def ping_worker(queue, results)
      while (ip = queue.pop(true) rescue nil)
        results[ip] = ping(ip)
      end
    end

    def ping(ip)
      argv = ["ping", "-c", "1", "-W", (@config.ping_timeout * 1000).to_s, ip]
      @runner.run(argv, @config.ping_timeout + 1)[:success]
    end

    def arp_table
      result = @runner.run(["arp", "-an"], ARP_TIMEOUT)
      raise Error, "arp failed" unless result[:success]
      parse_arp(result[:output])
    end

    def parse_arp(output)
      table = {}
      output.to_s.each_line { |line| add_arp(table, line) }
      table
    end

    def add_arp(table, line)
      return if line.include?("incomplete")
      match = line.match(/\((\d+\.\d+\.\d+\.\d+)\) at ([0-9a-fA-F:]+)/)
      table[match[1]] = normalize_mac(match[2]) if match
    end

    def normalize_mac(text)
      text.split(":").map { |octet| octet.rjust(2, "0") }.join(":").upcase
    end

    def build_records(addresses, reachable, table)
      addresses.filter_map do |ip|
        record = { ip: ip, mac: table[ip], online: reachable[ip] == true }
        record if record[:online] || record[:mac]
      end
    end

    def port_thread(ip, port)
      Thread.new { port if open?(ip, port) }
    end

    def open?(ip, port)
      @connector.call(ip, port, PORT_TIMEOUT)
    end
  end
end
