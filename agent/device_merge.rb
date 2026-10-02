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
      used = {}
      matches = match_macs(lookup, used)
      matches = match_ips(matches, lookup, used)
      devices(matches, used) + unregistered(records, used)
    end

    private

    def match_macs(lookup, used)
      @registry.devices.each_with_object({}) do |device, matches|
        matches[device.object_id] = take(lookup[device[:mac].upcase], used)
      end
    end

    def match_ips(matches, lookup, used)
      @registry.devices.each do |device|
        next if matches[device.object_id]
        matches[device.object_id] = take(lookup[device[:ip]], used)
      end
      matches
    end

    def take(record, used)
      return nil if record.nil? || used[record.object_id]
      used[record.object_id] = true
      record
    end

    def devices(matches, used)
      @registry.devices.map { |device| entry(matches[device.object_id] || offline(device), true, device[:name]) }
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
      records.select { |record| record[:online] && !used[record.object_id] }
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
