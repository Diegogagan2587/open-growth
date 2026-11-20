class AddStatusBeforeCancellationToIncomeEvents < ActiveRecord::Migration[8.1]
  def change
    add_column :income_events, :status_before_cancellation, :string
  end
end
