require "test_helper"

class Financial::PlanProjectionTest < ActiveSupport::TestCase
  setup do
    @account = Account.create!(name: "Projection household")
    Current.account = @account
    @category = Category.create!(account: @account, name: "Projection expense")
    @asset = Financial::Asset.create!(
      account: @account,
      name: "Projection checking",
      account_type: "checking",
      status: "active",
      opening_balance: 0
    )
  end

  teardown do
    Current.account = nil
  end

  test "keeps projected consumption separate from unplanned actual entries" do
    plan = IncomeEvent.create!(
      account: @account,
      description: "Payday plan",
      expected_date: Date.new(2026, 8, 15),
      expected_amount: 1_000,
      status: "pending"
    )
    PlannedExpense.create!(
      account: @account,
      income_event: plan,
      category: @category,
      description: "Rent",
      amount: 700,
      status: "pending_to_pay",
      position: 1,
      financial_account: @asset
    )
    Financial::Entry.create!(
      account: @account,
      income_event: plan,
      category: @category,
      description: "Unexpected medicine",
      amount: 100,
      entry_date: plan.expected_date,
      entry_type: "outflow",
      financial_account: @asset
    )

    projection = Financial::PlanProjection.for(plan)

    assert_equal 1_000.to_d, projection.expected_funding
    assert_equal 700.to_d, projection.planned_consumption
    assert_equal 300.to_d, projection.ending_balance
  end

  test "multiple funding sources replace the compatible event amount" do
    plan = Financial::Plan.create!(
      account: @account,
      name: "Multi-source plan",
      planned_for: Date.current,
      expected_amount: 1
    )
    plan.funding_sources.create!(account: @account, description: "Salary", expected_amount: 100, expected_date: Date.current)
    plan.funding_sources.create!(account: @account, description: "Refund", expected_amount: 25, expected_date: Date.current, kind: "refund")

    assert_equal 125.to_d, Financial::PlanProjection.for(plan).expected_funding
  end

  test "carries projected deficits across budget periods in planned date order" do
    first_period = BudgetPeriod.create!(account: @account, name: "July", start_date: Date.new(2026, 7, 1), end_date: Date.new(2026, 7, 31))
    second_period = BudgetPeriod.create!(account: @account, name: "August", start_date: Date.new(2026, 8, 1), end_date: Date.new(2026, 8, 31))
    first_plan = IncomeEvent.create!(account: @account, budget_period: first_period, description: "July plan", expected_date: Date.new(2026, 7, 31), expected_amount: 500, status: "pending")
    second_plan = IncomeEvent.create!(account: @account, budget_period: second_period, description: "August plan", expected_date: Date.new(2026, 8, 15), expected_amount: 400, status: "pending")
    PlannedExpense.create!(account: @account, income_event: first_plan, category: @category, description: "July rent", amount: 800, status: "pending_to_pay", position: 1, financial_account: @asset)

    projection = Financial::PlanProjection.for(second_plan)

    assert_equal(-300.to_d, projection.opening_balance)
    assert_equal 100.to_d, projection.ending_balance
  end

  test "shows ordered running balances and the first transaction that creates a deficit" do
    plan = IncomeEvent.create!(account: @account, description: "Ordered plan", expected_date: Date.new(2026, 9, 1), expected_amount: 500, status: "pending")
    first = PlannedExpense.create!(account: @account, income_event: plan, category: @category, description: "Food", amount: 300, status: "pending_to_pay", position: 1, financial_account: @asset)
    movement = PlannedExpense.create!(account: @account, income_event: plan, description: "Move cash", amount: 100, status: "pending_to_pay", position: 2, financial_account: @asset, counterparty_financial_account: Financial::Asset.create!(account: @account, name: "Projection savings", account_type: "savings", status: "active", opening_balance: 0))
    deficit = PlannedExpense.create!(account: @account, income_event: plan, category: @category, description: "Utilities", amount: 250, status: "pending_to_pay", position: 3, financial_account: @asset)

    projection = Financial::PlanProjection.for(plan)

    assert_equal [ [ first.id, 200.to_d ], [ movement.id, 200.to_d ], [ deficit.id, -50.to_d ] ], projection.rows.map { |row| [ row.transaction.id, row.balance ] }
    assert_equal deficit, projection.first_deficit_transaction
  end
end
