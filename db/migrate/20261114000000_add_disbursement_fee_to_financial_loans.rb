class AddDisbursementFeeToFinancialLoans < ActiveRecord::Migration[8.1]
  def change
    add_column :financial_loans, :disbursement_fee_amount, :decimal, precision: 12, scale: 2, default: 0, null: false
    add_reference :financial_loans, :disbursement_fee_entry, foreign_key: { to_table: :financial_entries }
  end
end
