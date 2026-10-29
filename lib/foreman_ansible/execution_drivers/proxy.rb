# frozen_string_literal: true

module ForemanAnsible
  module ExecutionDrivers
    class Proxy
      class << self
        def execution_action(_job_invocation)
          ::Actions::RemoteExecution::RunHostsJob
        end

        def humanized_name
          N_('Smart Proxy')
        end
      end
    end
  end
end
