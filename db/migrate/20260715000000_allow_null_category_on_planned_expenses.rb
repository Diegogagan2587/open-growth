class AllowNullCategoryOnPlannedExpenses < ActiveRecord::Migration[8.0]
  def change
    change_column_null :planned_expenses, :category_id, true
  end
end
