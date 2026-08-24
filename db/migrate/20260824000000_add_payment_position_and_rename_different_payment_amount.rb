class AddPaymentPositionAndRenameDifferentPaymentAmount < ActiveRecord::Migration[8.0]
  def change
    rename_column :financial_loans, :final_payment_amount, :different_payment_amount
    add_column :financial_loans, :different_payment_position, :string, null: false, default: "final"
  end
end
