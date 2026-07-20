class ExpandFinancialLoanInterestRate < ActiveRecord::Migration[8.0]
  def up
    change_column :financial_loans, :interest_rate, :decimal, precision: 8, scale: 3
  end

  def down
    change_column :financial_loans, :interest_rate, :decimal, precision: 6, scale: 3
  end
end
