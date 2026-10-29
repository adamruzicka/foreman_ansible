class AddAnsibleExecutionDriverToJobInvocations < ActiveRecord::Migration[7.0]
  def change
    add_column :job_invocations, :ansible_execution_driver, :string
  end
end
