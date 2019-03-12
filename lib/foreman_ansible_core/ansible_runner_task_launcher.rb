require 'fileutils'

module ForemanAnsibleCore
  class AnsibleRunnerTaskLauncher < ForemanTasksCore::TaskLauncher::AbstractGroup
    class AnsibleRunnerRunner < ForemanTasksCore::Runner::Parent
      include ForemanTasksCore::Runner::Command

      def initialize(input, suspended_action:)
        super input, suspended_action: suspended_action
        @inventory = rebuild_inventory(input)
        @playbook = input.values.first[:input][:action_input][:script]
        @root = working_dir
      end

      def start
        prepare_directory_structure
        write_inventory
        write_playbook
        start_ansible_runner
      end

      def refresh
        if super
          @counter ||= 1
          @uuid ||= File.basename(Dir["#{@root}/artifacts/*"].first)
          loop do
            job_event_dir = File.join(@root, 'artifacts', @uuid, 'job_events')
            event = Dir["#{job_event_dir}/#{@counter}-*"].first
            return if event.nil?
            @counter += 1 if handle_event_file(event)
          end
        end
      end

      private

      def handle_event_file(event_file)
        begin
          event = JSON.parse(File.read(event_file))
          if (hostname = event['event_data']['host'])
            handle_host_event(hostname, event)
          else
            handle_broadcast_data(event)
          end
          true
        rescue JSON::ParserError
          nil
        end
      end

      def handle_host_event(hostname, event)
        publish_data_for(hostname, event['stdout'], 'stdout')
        case event['event']
        when 'runner_on_unreachable'
          publish_exit_status_for(hostname, 1)
        when 'runner_on_failed'
          publish_exit_status_for(hostname, 2) if event['ignore_errors'].nil?
        end
      end

      def handle_broadcast_data(event)
        if event['event'] == 'playbook_on_stats'
          header, *rows = event['stdout'].strip.lines.map(&:chomp)
          @outputs.keys.select { |key| key.is_a? String }.each do |host|
            line = rows.find { |row| row =~ /#{host}/ }
            publish_data_for(host, [header, line].join("\n"), 'stdout')
          end
        else
          broadcast_data(event['stdout'], 'stdout')
        end
      end

      def write_inventory
        inventory_script = <<~EOF
          #!/bin/sh
          cat <<-EOS
          #{JSON.dump(@inventory)}
          EOS
        EOF
        path = File.join(@root, 'inventory', 'hosts')
        File.write(path, inventory_script)
        File.chmod(0755, path)
      end

      def write_playbook
        File.write(File.join(@root, 'project', 'playbook.yml'), @playbook)
      end

      def start_ansible_runner
        command = ['ansible-runner', 'run', @root, '-p', 'playbook.yml']
        initialize_command *command
      end

      def prepare_directory_structure
        inner = %w(inventory project).map { |part| File.join(@root, part) }
        ([@root] + inner).each do |path|
          FileUtils.mkdir_p path
        end
      end

      # Each per-host task has inventory only for itself, we must
      # collect all the partial inventories into one large inventory
      # containing all the hosts.
      def rebuild_inventory(input)
        action_inputs = input.values.map { |hash| hash[:input][:action_input] }
        hostnames = action_inputs.map { |hash| hash[:name] }
        inventories = action_inputs.map { |hash| JSON.parse(hash[:ansible_inventory]) }
        host_vars = inventories.map { |i| i['_meta']['hostvars'] }.reduce(&:merge)

        { 'all' => { 'hosts' => hostnames,
                     'vars' => inventories.first['all']['vars'] },
         '_meta' => { 'hostvars' => host_vars } }
      end

      def working_dir
        return @root if @root
        dir = ForemanAnsibleCore.settings[:working_dir]
        @tmp_working_dir = true
        if dir.nil?
          Dir.mktmpdir
        else
          Dir.mktmpdir(nil, File.expand_path(dir))
        end
      end
    end

    def group_runner_input(input)
      super(input).reduce({}) do |acc, (_id, data)|
        acc.merge(data[:input]['action_input']['name'] => data)
      end
    end

    def operation
      'ansible-runner'
    end

    def self.group_runner_class
      AnsibleRunnerRunner
    end

    def self.input_format
      {
        $UUID => {
          :execution_plan_id => $EXECUTION_PLAN_UUID,
          :run_step_id => Integer,
          :input => {
            :action_class => Class,
            :action_input => {
              "ansible_inventory"=> String,
              "hostname"=>"127.0.0.1",
              "script"=>"---\n- hosts: all\n  tasks:\n    - shell: |\n        true\n      register: out\n    - debug: var=out"
            }
          }
        }
      }
    end
  end
end

if defined?(SmartProxyDynflowCore)
  SmartProxyDynflowCore::TaskLauncherRegistry.register('ansible-runner',
                                                       ForemanAnsibleCore::AnsibleRunnerTaskLauncher)
  SmartProxyDynflowCore::TaskLauncherRegistry.register('ansible-playbook',
                                                       ForemanTasksCore::TaskLauncher::Batch)
end