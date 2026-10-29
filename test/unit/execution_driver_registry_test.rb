# frozen_string_literal: true

require 'test_plugin_helper'

class ExecutionDriverRegistryTest < ActiveSupport::TestCase
  class AlternativeAction; end

  class AlternativeDriver
    class << self
      def execution_action(_job_invocation)
        AlternativeAction
      end
    end
  end

  class Invocation
    include ActiveModel::Model
    include ActiveModel::Validations::Callbacks
    include ForemanAnsible::JobInvocationExtensions

    attr_accessor :ansible_execution_driver, :pattern_template_invocations
  end

  test 'registers the proxy driver by default' do
    assert_equal ForemanAnsible::ExecutionDrivers::Proxy,
      ForemanAnsible.execution_drivers.fetch(:proxy)
  end

  test 'a new registry exposes no optional drivers' do
    registry = ForemanAnsible::ExecutionDriverRegistry.new

    assert_not registry.registered?(:aap)
  end

  test 'selects an action from the driver persisted on the invocation' do
    ForemanAnsible.execution_drivers.register(:alternative, AlternativeDriver)
    invocation = stub(:ansible_execution_driver => 'alternative')

    assert_equal AlternativeAction,
      ForemanAnsible::AnsibleProvider.execution_action(invocation)
  end

  test 'uses the proxy action for invocations created before driver persistence' do
    invocation = stub(:ansible_execution_driver => nil)

    assert_equal Actions::RemoteExecution::RunHostsJob,
      ForemanAnsible::AnsibleProvider.execution_action(invocation)
  end

  test 'locks the global driver onto a newly created Ansible invocation' do
    ForemanAnsible.execution_drivers.register(:alternative, AlternativeDriver)
    Setting.stubs(:[]).with(:ansible_execution_driver).returns('alternative')
    template = stub(:provider_type => 'Ansible')
    invocation = Invocation.new(:pattern_template_invocations => [stub(:template => template)])

    invocation.valid?(:create)

    assert_equal 'alternative', invocation.ansible_execution_driver
    Setting.stubs(:[]).with(:ansible_execution_driver).returns('proxy')
    assert_equal AlternativeAction,
      ForemanAnsible::AnsibleProvider.execution_action(invocation)
  end

  test 'does not select an Ansible driver for other providers' do
    Setting.expects(:[]).with(:ansible_execution_driver).never
    template = stub(:provider_type => 'Script')
    invocation = Invocation.new(:pattern_template_invocations => [stub(:template => template)])

    invocation.valid?(:create)

    assert_nil invocation.ansible_execution_driver
  end

  test 'does not select an Ansible driver for mixed-provider invocations' do
    Setting.expects(:[]).with(:ansible_execution_driver).never
    templates = %w[Ansible Script].map { |type| stub(provider_type: type) }
    invocations = templates.map { |template| stub(template: template) }
    invocation = Invocation.new(pattern_template_invocations: invocations)

    invocation.valid?(:create)

    assert_nil invocation.ansible_execution_driver
  end
end
