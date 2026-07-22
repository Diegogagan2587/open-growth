class DashboardController < ApplicationController
  MAX_PENDING_TASKS = 5
  PRIORITY_ORDER = { "high" => 0, "medium" => 1, "low" => 2 }.freeze

  def index
    @due_soon_tasks = RecurringTask.for_account(Current.account).pending.by_next_due.limit(5) if Current.account
  end

  private

  def pending_task_sort_key(task)
    due_date = task.is_a?(RecurringTask) ? task.next_due_date : task.due_date
    priority = task.is_a?(Projects::Task) ? PRIORITY_ORDER.fetch(task.priority, PRIORITY_ORDER["medium"]) : PRIORITY_ORDER["medium"]

    [ due_date.nil? ? 1 : 0, due_date || Date.current, priority, -task.created_at.to_i ]
  end
end
