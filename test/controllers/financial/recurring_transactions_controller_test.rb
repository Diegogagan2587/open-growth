require "test_helper"

class Financial::RecurringTransactionsControllerTest < ActionDispatch::IntegrationTest
  setup do
    @user = users(:one)
    @account = accounts(:one)
    @category = categories(:one)
    @checking = Financial::Account.create!(account: @account, name: "Recurring checking", account_group: "asset", account_type: "checking", status: "active", opening_balance: 0)
    @plan = Financial::Plan.create!(account: @account, name: "Recurring plan", planned_for: Date.current)
    @recurring = Financial::RecurringTransaction.create!(account: @account, category: @category, source_account: @checking, name: "Rent", amount: 900, frequency: "monthly", transaction_kind: "outflow", budget_consuming: true, importance: "essential", status: "active")
    sign_in_as(@user, @account)
  end

  teardown { Current.reset }

  test "canonical recurring transaction pages render" do
    get finance_recurring_transactions_path
    assert_response :success
    assert_select "a", text: "Rent"

    get finance_recurring_transaction_path(@recurring)
    assert_response :success
  end

  test "form uses account routing instead of a manually selected kind" do
    get edit_finance_recurring_transaction_path(@recurring)

    assert_response :success
    assert_select "select[name='financial_recurring_transaction[source_account_id]']"
    assert_select "select[name='financial_recurring_transaction[destination_account_id]']"
    assert_select "select[name='financial_recurring_transaction[transaction_kind]']", count: 0
  end

  test "quick pick creates a linked snapshot in the selected plan" do
    assert_difference("Financial::PlannedTransaction.count", 1) do
      post finance_planned_transactions_path, params: {
        planned_transaction: {
          plan_id: @plan.id,
          recurring_transaction_id: @recurring.id,
          planned_execution_date: Date.current
        }
      }
    end

    occurrence = Financial::PlannedTransaction.order(:id).last
    assert_equal @recurring, occurrence.recurring_transaction
    assert_equal 900.to_d, occurrence.planned_amount
    assert occurrence.budget_consuming?
    assert_redirected_to finance_plan_path(@plan)
  end

  test "quick pick cannot use another household recurrence" do
    other = accounts(:two)
    other_category = Category.create!(account: other, name: "Other recurring")
    other_source = Financial::Account.create!(account: other, name: "Other source", account_group: "asset", account_type: "checking", status: "active", opening_balance: 0)
    foreign = Financial::RecurringTransaction.create!(account: other, category: other_category, source_account: other_source, name: "Foreign", amount: 1, frequency: "monthly", transaction_kind: "outflow", budget_consuming: true, importance: "normal", status: "active")

    assert_no_difference("Financial::PlannedTransaction.count") do
      post finance_planned_transactions_path, params: { planned_transaction: { plan_id: @plan.id, recurring_transaction_id: foreign.id } }
    end
    assert_response :not_found
  end
end
