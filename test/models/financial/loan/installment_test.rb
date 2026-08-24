require "test_helper"

class Financial::Loan::InstallmentTest < ActiveSupport::TestCase
  test "uses the namespaced model and existing table" do
    assert_equal "financial_loan_installments", Financial::Loan::Installment.table_name
    assert_not Object.const_defined?("Financial::LoanInstallment")
  end

  test "marks a directly edited due date as manual" do
    account = Account.create!(name: "Installment model tenant")
    loan = Financial::Loan.create!(account: account, name: "Loan", principal_amount: 100, lifecycle_status: "simulated")
    installment = Financial::Loan::Installment.create!(account: account, financial_loan: loan, installment_number: 1, due_date: Date.new(2026, 9, 15), expected_amount: 100, expected_principal: 100, expected_interest: 0)

    installment.edit_due_date!(Date.new(2026, 9, 20))

    assert_equal Date.new(2026, 9, 20), installment.reload.due_date
    assert installment.manual_due_date
  end
end
