class AddFirstPaymentDateToFinancialLoans < ActiveRecord::Migration[8.1]
  def change
    add_column :financial_loans, :first_payment_date, :date
  end
end
