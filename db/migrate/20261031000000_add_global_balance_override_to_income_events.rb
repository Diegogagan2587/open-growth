class AddGlobalBalanceOverrideToIncomeEvents < ActiveRecord::Migration[8.1]
  def change
    add_column :income_events, :global_balance_override, :decimal, precision: 12, scale: 2
  end
end
