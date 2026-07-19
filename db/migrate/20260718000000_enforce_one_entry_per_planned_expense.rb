class EnforceOneEntryPerPlannedExpense < ActiveRecord::Migration[8.0]
  def change
    add_index :financial_entries,
      :planned_expense_id,
      unique: true,
      where: "planned_expense_id IS NOT NULL",
      name: "index_financial_entries_on_unique_planned_expense"
  end
end
