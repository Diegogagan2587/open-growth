class DashboardController < ApplicationController
  MAX_PENDING_TASKS = 5
  PRIORITY_ORDER = { "high" => 0, "medium" => 1, "low" => 2 }.freeze

  def index
    @user = Current.user.name
    @pending_tasks = Current.account ? combined_pending_tasks : []
  end

  private

  def combined_pending_tasks
    recurring_tasks = RecurringTask.for_account(Current.account)
      .pending
      .includes(:task_area)
      .order(next_due_date: :asc, created_at: :desc)
      .limit(MAX_PENDING_TASKS)

    project_tasks = Projects::Task.for_account(Current.account)
      .pending
      .includes(:project)
      .order(Arel.sql(<<~SQL.squish))
        CASE WHEN due_date IS NULL THEN 1 ELSE 0 END,
        due_date ASC,
        CASE priority WHEN 'high' THEN 0 WHEN 'medium' THEN 1 ELSE 2 END,
        created_at DESC
      SQL
      .limit(MAX_PENDING_TASKS)

    (recurring_tasks.to_a + project_tasks.to_a)
      .sort_by { |task| pending_task_sort_key(task) }
      .first(MAX_PENDING_TASKS)
  end

  def pending_task_sort_key(task)
    due_date = task.is_a?(RecurringTask) ? task.next_due_date : task.due_date
    priority = task.is_a?(Projects::Task) ? PRIORITY_ORDER.fetch(task.priority, PRIORITY_ORDER["medium"]) : PRIORITY_ORDER["medium"]

    [ due_date.nil? ? 1 : 0, due_date || Date.current, priority, -task.created_at.to_i ]
  end
end
