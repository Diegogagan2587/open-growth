require "test_helper"

class Financial::PlanActualsTest < ActiveSupport::TestCase
  setup do
    @account = Account.create!(name: "Actuals household")
    Current.account = @account
    @category = Category.create!(account: @account, name: "Actual consumption")
    @asset = Financial::Asset.create!(account: @account, name: "Actual checking", account_type: "checking", status: "active", opening_balance: 0)
  end

  teardown do
    Current.account = nil
  end

  test "derives actual funding and consumption only from entries" do
    plan = IncomeEvent.create!(account: @account, description: "Actual plan", expected_date: Date.new(2026, 8, 15), expected_amount: 1_000, status: "pending")
    PlannedExpense.create!(account: @account, income_event: plan, category: @category, description: "Unapplied rent", amount: 700, status: "pending_to_pay")
    Financial::Entry.create!(account: @account, income_event: plan, financial_account: @asset, description: "Partial salary", amount: 800, entry_date: plan.expected_date, entry_type: "inflow")
    Financial::Entry.create!(account: @account, income_event: plan, financial_account: @asset, category: @category, description: "Medicine", amount: 100, entry_date: plan.expected_date, entry_type: "outflow")

    actuals = Financial::PlanActuals.for(plan)

    assert_equal 800.to_d, actuals.actual_funding
    assert_equal 100.to_d, actuals.actual_consumption
    assert_equal 700.to_d, actuals.ending_balance
  end

  test "carries actual results across plans in planned date order" do
    first = IncomeEvent.create!(account: @account, description: "First actual plan", expected_date: Date.new(2026, 8, 1), expected_amount: 5_000, status: "pending")
    second = IncomeEvent.create!(account: @account, description: "Second actual plan", expected_date: Date.new(2026, 8, 15), expected_amount: 5_000, status: "pending")
    Financial::Entry.create!(account: @account, income_event: first, financial_account: @asset, description: "Received", amount: 400, entry_date: first.expected_date, entry_type: "inflow")
    Financial::Entry.create!(account: @account, income_event: first, financial_account: @asset, category: @category, description: "Consumed", amount: 600, entry_date: first.expected_date, entry_type: "outflow")
    Financial::Entry.create!(account: @account, income_event: second, financial_account: @asset, description: "Received later", amount: 500, entry_date: second.expected_date, entry_type: "inflow")

    actuals = Financial::PlanActuals.for(second)

    assert_equal(-200.to_d, actuals.opening_balance)
    assert_equal 300.to_d, actuals.ending_balance
  end
end
