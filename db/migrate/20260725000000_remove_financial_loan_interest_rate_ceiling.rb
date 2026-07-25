class RemoveFinancialLoanInterestRateCeiling < ActiveRecord::Migration[8.0]
  def change
    change_column :financial_loans, :interest_rate, :decimal
  end
end
