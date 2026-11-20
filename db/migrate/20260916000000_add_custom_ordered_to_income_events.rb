class AddCustomOrderedToIncomeEvents < ActiveRecord::Migration[8.1]
  def change
    add_column :income_events, :custom_ordered, :boolean, default: false, null: false
  end
end
