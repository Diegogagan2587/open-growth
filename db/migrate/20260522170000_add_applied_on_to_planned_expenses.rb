class AddAppliedOnToPlannedExpenses < ActiveRecord::Migration[8.1]
  def change
    add_column :planned_expenses, :applied_on, :date
    add_index :planned_expenses, :applied_on
  end
end
