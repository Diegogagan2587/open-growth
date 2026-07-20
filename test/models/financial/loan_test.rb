require "test_helper"

class Financial::LoanTest < ActiveSupport::TestCase
  test "simulation creates no debt and activation disburses only once" do
    account = Account.create!(name: "Loan Tenant")
    Current.account = account
    liability = Financial::Liability.create!(account: account, name: "Loan", liability_type: "personal_credit", status: "active", opening_balance: 0)
    asset = Financial::Asset.create!(account: account, name: "Checking", account_type: "checking", status: "active", opening_balance: 0)
    plan = Financial::Plan.create!(account: account, name: "Borrowing", planned_for: Date.current, expected_amount: 1)

    loan = Financial::Loan.create!(
      account: account,
      name: "Personal loan",
      principal_amount: 1_000,
      lifecycle_status: "simulated"
    )
    assert_equal 0, loan.entries.count

    loan.update!(liability: liability, destination_asset: asset)
    first = Financial::Loans::ActivateService.call(loan: loan, plan: plan)
    second = Financial::Loans::ActivateService.call(loan: loan.reload, plan: plan)

    assert first.success?
    assert second.success?
    assert_equal first.entry, second.entry
    assert_equal 1, loan.entries.where(entry_type: "loan_disbursement").count
    assert_equal 1_000.to_d, loan.actual_balance
    assert_equal 1_000.to_d, liability.current_balance
  ensure
    Current.account = nil
  end
end
