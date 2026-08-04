class AddPlanCommitmentToPlannedExpenses < ActiveRecord::Migration[8.0]
  def change
    add_column :planned_expenses, :commits_plan_funds, :boolean, null: false, default: false
  end
end
