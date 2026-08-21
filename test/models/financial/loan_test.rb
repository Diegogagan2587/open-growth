require "test_helper"

class Financial::LoanTest < ActiveSupport::TestCase
  test "interest rate must be nonnegative" do
    loan = Financial::Loan.new(name: "Invalid rate", principal_amount: 1, interest_rate: -0.001)

    assert_not loan.valid?
    assert_includes loan.errors[:interest_rate], "must be greater than or equal to 0"
  end

  test "simulation creates no debt and disbursement activates only once" do
    account = Account.create!(name: "Loan household")
    Current.account = account
    liability = Financial::Account.create!(account: account, name: "Loan", account_group: "liability", account_type: "personal_credit", status: "active", opening_balance: 0)
    asset = Financial::Account.create!(account: account, name: "Checking", account_group: "asset", account_type: "checking", status: "active", opening_balance: 0)
    plan = Financial::Plan.create!(account: account, name: "Borrowing", planned_for: Date.current)

    loan = Financial::Loan.create!(
      account: account,
      name: "Personal loan",
      principal_amount: 1_000,
      lifecycle_status: "simulated"
    )
    assert_equal 0, loan.transactions.count

    loan.update!(liability_account: liability, destination_account: asset)
    first = Financial::Loan::Disbursement.create(loan: loan, plan: plan)
    second = Financial::Loan::Disbursement.create(loan: loan.reload, plan: plan)

    assert first.success?
    assert second.success?
    assert_equal first.transaction, second.transaction
    assert_equal 1, loan.transactions.where(transaction_type: "loan_disbursement").count
    assert_equal 1_000.to_d, loan.actual_balance
    assert_equal 1_000.to_d, liability.current_balance
  ensure
    Current.account = nil
  end
end
