class AddEntryTimeToFinancialEntries < ActiveRecord::Migration[8.1]
  def change
    add_column :financial_transactions, :entry_time, :time
  end
end
