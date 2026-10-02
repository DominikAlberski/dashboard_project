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
      used = []
      registered(lookup, used) + unregistered(records, used)
    end

    private

    def registered(lookup, used)
      @registry.devices.map { |device| registered_entry(device, match(device, lookup), used) }
    end

    def registered_entry(device, record, used)
      used << record if record
      entry(record || offline(device), true, device[:name])
    end

    def offline(device)
      { ip: device[:ip], mac: device[:mac], online: false }
    end

    def match(device, lookup)
      lookup[device[:mac].upcase] || lookup[device[:ip]]
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
      records.select { |record| record[:online] && !used.include?(record) }
             .map { |record| entry(record, false, nil) }
    end

    def entry(record, registered, name)
      record.merge(name: name, registered: registered).slice(:name, :ip, :mac, :online, :registered)
    end
  end
end
