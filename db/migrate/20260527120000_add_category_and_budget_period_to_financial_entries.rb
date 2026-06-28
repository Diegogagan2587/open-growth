class AddCategoryAndBudgetPeriodToFinancialEntries < ActiveRecord::Migration[8.1]
  def change
    add_reference :financial_entries, :category, foreign_key: true
    add_reference :financial_entries, :budget_period, foreign_key: true
  end
end
