class NameFinancialBudgetAllocationsAndSavingsGoals < ActiveRecord::Migration[8.1]
  def change
    rename_table :budget_line_items, :financial_budget_allocations
    rename_table :expense_templates, :financial_savings_goals
    rename_column :financial_planned_transactions, :expense_template_id, :savings_goal_id
  end
end
