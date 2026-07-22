class DashboardController < ApplicationController
  MAX_PENDING_TASKS = 5
  PRIORITY_ORDER = { "high" => 0, "medium" => 1, "low" => 2 }.freeze

  def index
    @due_soon_tasks = RecurringTask.for_account(Current.account).pending.by_next_due.limit(5) if Current.account
  end
end
