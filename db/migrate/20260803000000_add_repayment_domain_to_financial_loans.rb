class AddRepaymentDomainToFinancialLoans < ActiveRecord::Migration[8.0]
  def up
    add_column :financial_loans, :repayment_basis, :string
    add_column :financial_loans, :final_payment_amount, :decimal, precision: 12, scale: 2
    add_reference :financial_loans, :interest_category, foreign_key: { to_table: :categories }
    add_reference :financial_loan_installments, :interest_entry, foreign_key: { to_table: :financial_transactions }

    execute <<~SQL.squish
      UPDATE financial_loans
      SET repayment_basis = CASE
        WHEN payment_amount IS NOT NULL THEN 'payment_amounts'
        WHEN interest_rate IS NOT NULL THEN 'annual_rate'
      END
    SQL
  end

  def down
    remove_reference :financial_loan_installments, :interest_entry, foreign_key: { to_table: :financial_transactions }
    remove_reference :financial_loans, :interest_category, foreign_key: { to_table: :categories }
    remove_column :financial_loans, :final_payment_amount
    remove_column :financial_loans, :repayment_basis
  end
end
