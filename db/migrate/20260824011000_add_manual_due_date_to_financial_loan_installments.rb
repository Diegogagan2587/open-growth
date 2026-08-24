class AddManualDueDateToFinancialLoanInstallments < ActiveRecord::Migration[8.1]
  def change
    add_column :financial_loan_installments, :manual_due_date, :boolean, null: false, default: false
  end
end
