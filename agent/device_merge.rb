module Agent
  # DeviceMerge merges scan records with the registry for a status reply.
  class DeviceMerge
    def initialize(registry)
      @registry = registry
    end

    def offline_devices
      @registry.devices.map { |device| entry(offline(device), true, device[:name]) }
    end

    def merge(records)
      lookup = build_index(records)
      used = {}.compare_by_identity
      matches = match_macs(lookup, used)
      matches = match_ips(matches, lookup, used)
      devices(matches) + unregistered(records, used)
    end

    private

    def match_macs(lookup, used)
      matches = {}.compare_by_identity
      @registry.devices.each { |device| matches[device] = take(lookup[device[:mac].upcase], used) }
      matches
    end

    def match_ips(matches, lookup, used)
      @registry.devices.each do |device|
        next if matches[device]
        matches[device] = take(lookup[device[:ip]], used)
      end
      matches
    end

    def take(record, used)
      return nil if record.nil? || used.key?(record)
      used[record] = true
      record
    end

    def devices(matches)
      @registry.devices.map { |device| entry(matches[device] || offline(device), true, device[:name]) }
    end

    def offline(device)
      { ip: device[:ip], mac: device[:mac], online: false }
    end

    def build_index(records)
      records.each_with_object({}) do |record, map|
        add_to_index(map, record)
      end
    end

    def add_to_index(map, record)
      map[record[:mac].to_s.upcase] = record if record[:mac]
      map[record[:ip]] = record
    end

    def unregistered(records, used)
      records.select { |record| record[:online] && !used.key?(record) }
             .map { |record| entry(record, false, nil) }
    end

    def entry(record, registered, name)
      values = record.merge(name: name, registered: registered)
      values.slice(:name, :ip, :mac, :online, :registered).transform_values { |value| deep_freeze(value) }.freeze
    end

    def deep_freeze(value)
      value.frozen? ? value : value.dup.freeze
    end
  end
end
