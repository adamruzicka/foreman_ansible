# frozen_string_literal: true

require 'foreman-tasks'
require 'foreman_ansible/execution_driver_registry'
require 'foreman_ansible/execution_drivers/proxy'
require 'foreman_ansible/engine'

# Module required to start the Foreman Rails engine
module ForemanAnsible
  DEFAULT_EXECUTION_DRIVER = 'proxy'

  class << self
    def execution_drivers
      @execution_drivers ||= ExecutionDriverRegistry.new
    end
  end
end

ForemanAnsible.execution_drivers.register(ForemanAnsible::DEFAULT_EXECUTION_DRIVER, ForemanAnsible::ExecutionDrivers::Proxy)
