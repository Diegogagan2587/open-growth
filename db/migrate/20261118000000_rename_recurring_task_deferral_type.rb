class RenameRecurringTaskDeferralType < ActiveRecord::Migration[8.1]
  def up
    execute <<~SQL
      UPDATE dashboard_task_deferrals
      SET task_type = 'Projects::Task::Recurring'
      WHERE task_type = 'RecurringTask'
    SQL
  end

  def down
    execute <<~SQL
      UPDATE dashboard_task_deferrals
      SET task_type = 'RecurringTask'
      WHERE task_type = 'Projects::Task::Recurring'
    SQL
  end
end
