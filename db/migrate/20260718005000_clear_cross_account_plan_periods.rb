class ClearCrossAccountPlanPeriods < ActiveRecord::Migration[8.0]
  def up
    execute <<~SQL
      UPDATE income_events
      SET budget_period_id = NULL, updated_at = CURRENT_TIMESTAMP
      FROM budget_periods
      WHERE income_events.budget_period_id = budget_periods.id
        AND income_events.account_id <> budget_periods.account_id
    SQL
  end

  def down
    # The invalid association cannot be restored safely without guessing which
    # account or period was intended.
  end
end
