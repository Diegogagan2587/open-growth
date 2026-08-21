require "test_helper"

class Financial::FinanceSurfaceTest < ActionDispatch::IntegrationTest
  setup do
    @user = users(:one)
    @account = accounts(:one)
    @checking = Financial::Account.create!(account: @account, name: "Surface checking", account_group: "asset", account_type: "checking", status: "active", opening_balance: 0)
    @category = categories(:one)
    @plan = Financial::Plan.create!(account: @account, name: "Surface plan", planned_for: Date.current)
    @plan.funding_sources.create!(account: @account, description: "Salary", expected_amount: 100, expected_date: Date.current, expected_destination_account: @checking)
    Financial::PlannedTransaction.create!(account: @account, plan: @plan, category: @category, source_account: @checking, description: "Food", planned_amount: 20, kind: "outflow", execution_status: "pending", importance: "normal")
    @goal = Financial::SavingsGoal.create!(account: @account, category: @category, name: "Emergency", total_amount: 500, frequency: "monthly")
    @recurring = Financial::RecurringTransaction.create!(account: @account, category: @category, source_account: @checking, name: "Monthly food", amount: 50, frequency: "monthly", transaction_kind: "outflow", budget_consuming: true, importance: "normal", status: "active")
    sign_in_as(@user, @account)
  end

  teardown { Current.reset }

  test "canonical finance pages render through their own resources" do
    [ finance_path, finance_accounts_path, finance_account_path(@checking), finance_plans_path, finance_plan_path(@plan), finance_transactions_path, finance_savings_goals_path, finance_savings_goal_path(@goal), finance_recurring_transactions_path, finance_recurring_transaction_path(@recurring), finance_loans_path ].each do |path|
      get path
      assert_response :success, path
    end
  end

  test "legacy actual-record GET routes redirect one hop and expose no mutations" do
    get "/finance/entries"
    assert_redirected_to finance_transactions_path
    assert_not Rails.application.routes.recognize_path("/finance/entries", method: :post), "legacy POST route should not exist"
  rescue ActionController::RoutingError
    assert true
  end
end
