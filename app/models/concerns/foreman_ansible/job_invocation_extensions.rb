# frozen_string_literal: true

module ForemanAnsible
  module JobInvocationExtensions
    extend ActiveSupport::Concern

    included do
      before_validation :lock_ansible_execution_driver, :on => :create
    end

    private

    def lock_ansible_execution_driver
      provider_types = pattern_template_invocations.filter_map { |invocation| invocation.template&.provider_type }.uniq
      return unless provider_types == ['Ansible']

      self.ansible_execution_driver ||=
        Setting[:ansible_execution_driver].presence || ForemanAnsible::DEFAULT_EXECUTION_DRIVER
      return if ForemanAnsible.execution_drivers.registered?(ansible_execution_driver)

      errors.add(:ansible_execution_driver, _('is not registered: %s') % ansible_execution_driver)
    end
  end
end
