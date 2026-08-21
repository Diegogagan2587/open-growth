class RenameFinancialEntriesToTransactions < ActiveRecord::Migration[8.1]
  def up
    rename_table :financial_entries, :financial_transactions
    rename_column :financial_transactions, :entry_type, :transaction_type
    rename_column :financial_transactions, :entry_date, :transaction_date
    add_column :financial_transactions, :reconciled_at, :datetime
    add_index :financial_transactions, [ :account_id, :reconciled_at ], name: "index_financial_transactions_on_reconciliation"

    execute <<~SQL
      UPDATE financial_transactions
      SET transaction_type = CASE transaction_type
        WHEN 'inflow' THEN 'income'
        WHEN 'outflow' THEN 'expense'
        WHEN 'liability_charge' THEN 'expense'
        WHEN 'liability_payment' THEN 'debt_payment'
        ELSE transaction_type
      END
    SQL

    rename_column :financial_loan_installments, :payment_entry_id, :payment_transaction_id
    rename_column :shopping_items, :financial_entry_id, :financial_transaction_id

    add_index :financial_transactions,
      :financial_loan_id,
      unique: true,
      where: "financial_loan_id IS NOT NULL AND transaction_type = 'loan_disbursement'",
      name: "index_financial_transactions_on_unique_loan_disbursement"
  end

  def down
    remove_index :financial_transactions, name: "index_financial_transactions_on_unique_loan_disbursement"
    rename_column :shopping_items, :financial_transaction_id, :financial_entry_id
    rename_column :financial_loan_installments, :payment_transaction_id, :payment_entry_id
    execute <<~SQL
      UPDATE financial_transactions
      SET transaction_type = CASE transaction_type
        WHEN 'income' THEN 'inflow'
        WHEN 'expense' THEN 'outflow'
        WHEN 'debt_payment' THEN 'liability_payment'
        ELSE transaction_type
      END
    SQL
    remove_index :financial_transactions, name: "index_financial_transactions_on_reconciliation"
    remove_column :financial_transactions, :reconciled_at
    rename_column :financial_transactions, :transaction_date, :entry_date
    rename_column :financial_transactions, :transaction_type, :entry_type
    rename_table :financial_transactions, :financial_entries
  end
end
