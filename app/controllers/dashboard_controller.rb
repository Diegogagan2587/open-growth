class DashboardController < ApplicationController
  MAX_PENDING_TASKS = 5
  MAX_FINANCIAL_ACTIONS = 5
  FINANCIAL_LOOKAHEAD_DAYS = 14
  PRIORITY_ORDER = { "high" => 0, "medium" => 1, "low" => 2 }.freeze

  def index
    @user = Current.user.name
    @pending_tasks = Current.account ? combined_pending_tasks : []
    load_financial_actions if Current.account
  end

  private

  def combined_pending_tasks
    deferrals = Dashboard::TaskDeferral.where(account: Current.account, user: Current.user)
    deferred_recurring_ids = deferrals.where(task_type: "RecurringTask").select(:task_id)
    deferred_project_ids = deferrals.where(task_type: "Projects::Task").select(:task_id)

    recurring_tasks = RecurringTask.for_account(Current.account)
      .pending
      .where.not(id: deferred_recurring_ids)
      .includes(:task_area)
      .order(next_due_date: :asc, created_at: :desc)
      .limit(MAX_PENDING_TASKS)

    project_tasks = Projects::Task.for_account(Current.account)
      .pending
      .where.not(id: deferred_project_ids)
      .includes(:project)
      .order(Arel.sql(<<~SQL.squish))
        CASE WHEN due_date IS NULL THEN 1 ELSE 0 END,
        due_date ASC,
        CASE priority WHEN 'high' THEN 0 WHEN 'medium' THEN 1 ELSE 2 END,
        created_at DESC
      SQL
      .limit(MAX_PENDING_TASKS)

    available_tasks = (recurring_tasks.to_a + project_tasks.to_a)
      .sort_by { |task| pending_task_sort_key(task) }
      .first(MAX_PENDING_TASKS)
    return available_tasks if available_tasks.any?

    deferred_records = deferrals.order(:deferred_at, :id).to_a
    recurring_by_id = RecurringTask.for_account(Current.account)
      .pending
      .where(id: deferred_records.select { |record| record.task_type == "RecurringTask" }.map(&:task_id))
      .includes(:task_area)
      .index_by(&:id)
    projects_by_id = Projects::Task.for_account(Current.account)
      .pending
      .where(id: deferred_records.select { |record| record.task_type == "Projects::Task" }.map(&:task_id))
      .includes(:project)
      .index_by(&:id)

    deferred_records.filter_map do |record|
      if record.task_type == "RecurringTask"
        recurring_by_id[record.task_id]
      elsif record.task_type == "Projects::Task"
        projects_by_id[record.task_id]
      end
    end.first(MAX_PENDING_TASKS)
  end

  def load_financial_actions
    window_end = FINANCIAL_LOOKAHEAD_DAYS.days.from_now.to_date
    due_date_sql = "COALESCE(planned_expenses.due_date, planned_expenses.planned_for)"

    @pending_planned_transactions = Financial::PlannedTransaction.for_account(Current.account)
      .where(execution_status: "pending")
      .left_outer_joins(:plan)
      .where("planned_expenses.income_event_id IS NULL OR income_events.lifecycle_status IN (?)", %w[draft active])
      .where("#{due_date_sql} <= ?", window_end)
      .includes(:plan)
      .order(Arel.sql("#{due_date_sql} ASC"))
      .limit(MAX_FINANCIAL_ACTIONS)

    @expected_funding = Financial::FundingSource.where(account: Current.account, resolution: "pending")
      .joins(:financial_plan)
      .where(income_events: { lifecycle_status: %w[draft active] })
      .where(expected_date: ..window_end)
      .includes(:financial_plan)
      .order(:expected_date)
      .limit(MAX_FINANCIAL_ACTIONS)
  end

  def pending_task_sort_key(task)
    due_date = task.is_a?(RecurringTask) ? task.next_due_date : task.due_date
    priority = task.is_a?(Projects::Task) ? PRIORITY_ORDER.fetch(task.priority, PRIORITY_ORDER["medium"]) : PRIORITY_ORDER["medium"]

    [ due_date.nil? ? 1 : 0, due_date || Date.current, priority, -task.created_at.to_i ]
  end
end
