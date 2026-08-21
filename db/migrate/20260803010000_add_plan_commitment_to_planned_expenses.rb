class AddPlanCommitmentToPlannedExpenses < ActiveRecord::Migration[8.0]
  def up
    add_column :planned_expenses, :commits_plan_funds, :boolean, null: false, default: false
    add_column :financial_planned_transactions, :commits_plan_funds, :boolean, null: false, default: false

    execute <<~SQL
      UPDATE financial_planned_transactions canonical
      SET commits_plan_funds = legacy.commits_plan_funds
      FROM planned_expenses legacy
      WHERE canonical.legacy_planned_expense_id = legacy.id
    SQL
  end

  def down
    remove_column :financial_planned_transactions, :commits_plan_funds
    remove_column :planned_expenses, :commits_plan_funds
  end
end
