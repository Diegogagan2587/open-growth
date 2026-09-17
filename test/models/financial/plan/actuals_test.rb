require "test_helper"

class Financial::Plan::ActualsTest < ActiveSupport::TestCase
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
    plan = Financial::Plan.create!(account: @account, name: "Actual plan", planned_for: Date.new(2026, 8, 15), expected_amount: 1_000)
    PlannedExpense.create!(account: @account, income_event: plan, category: @category, description: "Unapplied rent", amount: 700, status: "pending_to_pay")
    source = plan.funding_sources.create!(account: @account, description: "Salary", expected_amount: 1_000, expected_date: plan.planned_for, expected_destination_asset: @asset)
    Financial::Entry.create!(account: @account, funding_source: source, financial_account: @asset, description: "Partial salary", amount: 800, entry_date: plan.expected_date, entry_type: "inflow")
    Financial::Entry.create!(account: @account, income_event: plan, financial_account: @asset, category: @category, description: "Medicine", amount: 100, entry_date: plan.expected_date, entry_type: "outflow")

    actuals = Financial::Plan::Actuals.for(plan)

    assert_equal 800.to_d, actuals.actual_funding
    assert_equal 100.to_d, actuals.actual_consumption
    assert_equal 700.to_d, actuals.ending_balance
  end

  test "keeps actual results local to one plan" do
    first = Financial::Plan.create!(account: @account, name: "First actual plan", planned_for: Date.new(2026, 8, 1), expected_amount: 5_000)
    second = Financial::Plan.create!(account: @account, name: "Second actual plan", planned_for: Date.new(2026, 8, 15), expected_amount: 5_000)
    first_source = first.funding_sources.create!(account: @account, description: "First funding", expected_amount: 400, expected_date: first.planned_for, expected_destination_asset: @asset)
    Financial::Entry.create!(account: @account, funding_source: first_source, financial_account: @asset, description: "Received", amount: 400, entry_date: first.expected_date, entry_type: "inflow")
    Financial::Entry.create!(account: @account, income_event: first, financial_account: @asset, category: @category, description: "Consumed", amount: 600, entry_date: first.expected_date, entry_type: "outflow")
    second_source = second.funding_sources.create!(account: @account, description: "Second funding", expected_amount: 500, expected_date: second.planned_for, expected_destination_asset: @asset)
    Financial::Entry.create!(account: @account, funding_source: second_source, financial_account: @asset, description: "Received later", amount: 500, entry_date: second.expected_date, entry_type: "inflow")

    actuals = Financial::Plan::Actuals.for(second)

    assert_equal 0.to_d, actuals.opening_balance
    assert_equal 500.to_d, actuals.ending_balance
  end

  test "actual funding includes only funding source receipts" do
    plan = Financial::Plan.create!(account: @account, name: "Receipt plan", planned_for: Date.current, expected_amount: 1)
    source = plan.funding_sources.create!(account: @account, description: "Salary", expected_amount: 500, expected_date: Date.current, expected_destination_asset: @asset)
    Financial::Entry.create!(account: @account, income_event: plan, financial_account: @asset, description: "Unrelated inflow", amount: 900, entry_date: Date.current, entry_type: "inflow")
    Financial::Entry.create!(account: @account, funding_source: source, financial_account: @asset, description: "Salary receipt", amount: 450, entry_date: Date.current, entry_type: "inflow")

    assert_equal 450.to_d, Financial::Plan::Actuals.for(plan).actual_funding
  end

  test "unplanned actual expenses contribute to consumption and reduce actual balance" do
    plan = Financial::Plan.create!(account: @account, name: "Unplanned actuals", planned_for: Date.current, expected_amount: 1)
    source = plan.funding_sources.create!(account: @account, description: "Funding", expected_amount: 500, expected_date: Date.current, expected_destination_asset: @asset)
    Financial::Entry.create!(account: @account, funding_source: source, financial_account: @asset, description: "Funding receipt", amount: 500, entry_date: Date.current, entry_type: "inflow")
    unplanned = Financial::Entry.create!(account: @account, income_event: plan, financial_account: @asset, category: @category, description: "Unexpected repair", amount: 125, entry_date: Date.current, entry_type: "outflow")

    actuals = Financial::Plan::Actuals.for(plan)

    assert_nil unplanned.planned_expense_id
    assert_equal 125.to_d, actuals.actual_consumption
    assert_equal 375.to_d, actuals.ending_balance
  end
end
