require "test_helper"

class Financial::Plans::CloseServiceTest < ActiveSupport::TestCase
  test "captures the actual ending result and keeps it stable" do
    account = Account.create!(name: "Close Tenant")
    Current.account = account
    asset = Financial::Asset.create!(account: account, name: "Checking", account_type: "checking", status: "active", opening_balance: 0)
    plan = Financial::Plan.create!(account: account, name: "July", planned_for: Date.current, expected_amount: 1)
    Financial::Entry.create!(account: account, income_event: plan, financial_account: asset, entry_type: "inflow", entry_date: Date.current, amount: 80, description: "Actual income")

    result = Financial::Plans::CloseService.call(plan: plan)

    assert result.success?
    assert_equal "closed", plan.reload.lifecycle_status
    assert_equal 80.to_d, plan.actual_ending_balance_at_close
    blocked = Financial::Entry.new(account: account, income_event: plan, financial_account: asset, entry_type: "inflow", entry_date: Date.current, amount: 10, description: "Late income")
    assert_not blocked.valid?
  ensure
    Current.account = nil
  end
end
