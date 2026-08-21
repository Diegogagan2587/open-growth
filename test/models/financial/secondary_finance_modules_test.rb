require "test_helper"

class Financial::SecondaryFinanceModulesTest < ActiveSupport::TestCase
  setup do
    @account = Account.create!(name: "Secondary finance household")
    @category = Category.create!(account: @account, name: "Goal")
    @checking = Financial::Account.create!(account: @account, name: "Checking", account_group: "asset", account_type: "checking", status: "active", opening_balance: 0)
    Current.account = @account
  end

  teardown { Current.reset }

  test "savings goal progress comes from actual transactions" do
    goal = Financial::SavingsGoal.create!(account: @account, category: @category, name: "Laptop", total_amount: 1_000, frequency: "monthly")
    plan = Financial::Plan.create!(account: @account, name: "August", planned_for: Date.current)
    planned = Financial::PlannedTransaction.create!(account: @account, plan: plan, savings_goal: goal, category: @category, source_account: @checking, description: "Save", planned_amount: 200, kind: "outflow", execution_status: "pending", importance: "normal")
    Financial::PlannedTransactions::Execution.create(planned_transaction: planned, attributes: { amount: 175 })

    assert_equal 175.to_d, goal.total_saved
    assert_equal 825.to_d, goal.remaining_amount
  end

  test "budget period includes projected carryover from earlier periods" do
    july = BudgetPeriod.create!(account: @account, name: "July", start_date: Date.new(2026, 7, 1), end_date: Date.new(2026, 7, 31), total_amount: 0)
    august = BudgetPeriod.create!(account: @account, name: "August", start_date: Date.new(2026, 8, 1), end_date: Date.new(2026, 8, 31), total_amount: 0)
    plan = Financial::Plan.create!(account: @account, budget_period: july, name: "July plan", planned_for: Date.new(2026, 7, 1))
    plan.funding_sources.create!(account: @account, description: "Salary", expected_amount: 500, expected_date: plan.planned_for, expected_destination_account: @checking)
    Financial::PlannedTransaction.create!(account: @account, plan: plan, category: @category, source_account: @checking, description: "Needs", planned_amount: 300, kind: "outflow", execution_status: "pending", importance: "normal")

    assert_equal 200.to_d, august.opening_balance
    assert_equal 200.to_d, august.remaining_budget
  end
end
