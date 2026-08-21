require "test_helper"

class Financial::Plans::CloseServiceTest < ActiveSupport::TestCase
  test "captures the actual ending result and keeps it stable" do
    account = Account.create!(name: "Close household")
    Current.account = account
    asset = Financial::Account.create!(account: account, name: "Checking", account_group: "asset", account_type: "checking", status: "active", opening_balance: 0)
    plan = Financial::Plan.create!(account: account, name: "July", planned_for: Date.current)
    plan.funding_sources.create!(account: account, description: "Expected income", expected_amount: 80, expected_date: Date.current, expected_destination_account: asset)
    Financial::Transaction.create!(account: account, plan: plan, destination_account: asset, transaction_type: "income", transaction_date: Date.current, amount: 80, description: "Actual income")

    result = Financial::Plans::CloseService.call(plan: plan)

    assert result.success?
    assert_equal "closed", plan.reload.lifecycle_status
    assert_equal 80.to_d, plan.actual_ending_balance_at_close
    blocked = Financial::Transaction.new(account: account, plan: plan, destination_account: asset, transaction_type: "income", transaction_date: Date.current, amount: 10, description: "Late income")
    assert_not blocked.valid?
  ensure
    Current.account = nil
  end
end
