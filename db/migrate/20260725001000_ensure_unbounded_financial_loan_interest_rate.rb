class EnsureUnboundedFinancialLoanInterestRate < ActiveRecord::Migration[8.1]
  def change
    change_column :financial_loans, :interest_rate, :decimal
  end
end
