# frozen_string_literal: true

module ForemanAnsible
  class ExecutionDriverRegistry
    class UnknownDriver < KeyError; end

    def initialize
      @drivers = {}
    end

    def register(name, adapter)
      @drivers[name.to_s] = adapter
    end

    def fetch(name)
      @drivers.fetch(name.to_s) do
        raise UnknownDriver.new("Unknown Ansible execution driver: #{name}")
      end
    end

    def registered?(name)
      @drivers.key?(name.to_s)
    end

    def names
      @drivers.keys
    end
  end
end
