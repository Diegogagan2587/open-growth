require "test_helper"

class PlannedExpensesControllerTest < ActionDispatch::IntegrationTest
  def setup
    @user = users(:one)
    @account = accounts(:one)
    @income_event = income_events(:one)
    @category = categories(:one)
    @budget_period = BudgetPeriod.create!(
      name: "Planned Expense Test Period",
      start_date: Date.current.beginning_of_month,
      end_date: Date.current.end_of_month,
      total_amount: 2000,
      account: @account
    )
    @income_event.update!(budget_period: @budget_period)

    @source_account = Financial::Asset.create!(
      name: "Controller Checking",
      account: @account,
      account_type: "checking",
      status: "active",
      opening_balance: 1000.00
    )

    @destination_account = Financial::Asset.create!(
      name: "Controller Savings",
      account: @account,
      account_type: "savings",
      status: "active",
      opening_balance: 250.00
    )

    # Create session for authentication
    @session = @user.sessions.create!(
      user_agent: "Test Agent",
      ip_address: "127.0.0.1"
    )
  end

  # Helper to sign in by making a request to the sessions controller
  # This properly sets up the session cookie
  def sign_in
    # First, ensure the user has a password set in fixtures
    # Then sign in through the sessions controller
    post session_path, params: {
      email_address: @user.email_address,
      password: "password"  # From fixtures
    }
    # After signing in, set Current.account
    Current.account = @account
  end

  def teardown
    Current.account = nil
    Current.session = nil
  end

  test "should get new" do
    sign_in
    get new_income_event_planned_expense_path(@income_event)
    assert_response :success
    assert_select "h1", "New Planned Expense"
    assert_select "form"
    assert_select "select[name='planned_expense[source_selection]']"
    assert_select "select[name='planned_expense[destination_selection]']"
  end

  test "new action should load income events for assignment" do
    sign_in
    get new_income_event_planned_expense_path(@income_event)
    assert_response :success

    # Verify the form includes income event assignment section
    assert_select "h3", text: /Income Event Assignment/

    # Verify income events dropdown is present
    assert_select "select[name='planned_expense[income_event_id]']"

    # Verify at least the current income event is in the options
    assert_select "select[name='planned_expense[income_event_id]'] option[value='#{@income_event.id}']"
  end

  test "new action should load expense templates" do
    sign_in
    get new_income_event_planned_expense_path(@income_event)
    assert_response :success

    # Verify template selection section is present
    assert_select "h3", text: /Template Selection/
  end

  test "should create planned expense" do
    sign_in
    assert_difference("PlannedExpense.count") do
      post income_event_planned_expenses_path(@income_event), params: {
        planned_expense: {
          category_id: @category.id,
          description: "Test Expense",
          amount: 100.00,
          status: "pending_to_pay",
          source_selection: "asset:#{@source_account.id}"
        }
      }
    end

    assert_redirected_to income_event_planned_expenses_path(@income_event)
  end

  test "apply action creates routed transfer entry" do
    sign_in
    planned_expense = PlannedExpense.create!(
      income_event: @income_event,
      category: @category,
      account: @account,
      description: "Move funds to savings",
      amount: 125.00,
      status: "pending_to_pay",
      financial_account: @source_account,
      counterparty_financial_account: @destination_account
    )

    assert_no_difference("Expense.count") do
      assert_difference("Financial::Entry.count", 1) do
        patch apply_income_event_planned_expense_path(@income_event, planned_expense)
      end
    end

    assert_redirected_to income_event_planned_expenses_path(@income_event)
    assert_equal "transferred", planned_expense.reload.status
    assert_equal planned_expense.id, planned_expense.financial_entry.planned_expense_id
  end

  test "update to final status creates transaction for regular outflow" do
    sign_in
    planned_expense = PlannedExpense.create!(
      income_event: @income_event,
      category: @category,
      account: @account,
      description: "Finalize regular expense",
      amount: 90.00,
      status: "pending_to_pay",
      financial_account: @source_account
    )

    assert_difference("Financial::Entry.count", 1) do
      patch income_event_planned_expense_path(@income_event, planned_expense), params: {
        planned_expense: {
          category_id: @category.id,
          description: planned_expense.description,
          amount: planned_expense.amount,
          status: "paid",
          source_selection: "asset:#{@source_account.id}"
        }
      }
    end

    assert_redirected_to income_event_planned_expenses_path(@income_event)
    assert_equal "paid", planned_expense.reload.status
    assert planned_expense.financial_entry.present?
  end

  test "create_transaction builds missing entry for final status" do
    sign_in
    planned_expense = PlannedExpense.create!(
      income_event: @income_event,
      category: @category,
      account: @account,
      description: "Missing transaction recovery",
      amount: 40.00,
      status: "paid",
      financial_account: @source_account
    )

    assert_nil planned_expense.financial_entry

    assert_difference("Financial::Entry.count", 1) do
      post create_transaction_income_event_planned_expense_path(@income_event, planned_expense)
    end

    assert_redirected_to income_event_planned_expense_path(@income_event, planned_expense)
    assert planned_expense.reload.financial_entry.present?
  end

  test "should not create planned expense with invalid data" do
    sign_in
    assert_no_difference("PlannedExpense.count") do
      post income_event_planned_expenses_path(@income_event), params: {
        planned_expense: {
          category_id: nil,
          description: "",
          amount: nil,
          status: ""
        }
      }
    end

    assert_response :unprocessable_entity
    # Verify form is re-rendered with income_events available
    assert_select "select[name='planned_expense[income_event_id]']"
  end

  test "edit form shows current amount and edit mode for template selector" do
    sign_in
    planned_expense = PlannedExpense.create!(
      income_event: @income_event,
      category: @category,
      account: @account,
      description: "Rent",
      amount: 250.50,
      status: "pending_to_pay",
      source_selection: "asset:#{@source_account.id}"
    )

    get edit_income_event_planned_expense_path(@income_event, planned_expense)
    assert_response :success
    assert_select "h1", "Edit Planned Expense"

    # Amount field must show the current value (not a placeholder) so the template-selector
    # controller preserves it when editing
    assert_select "input[name='planned_expense[amount]']" do |inputs|
      assert_equal 1, inputs.size, "Expected one amount input"
      value = inputs.first["value"]
      assert value.present?, "Amount input should have a value when editing"
      assert_in_delta 250.50, value.to_f, 0.01, "Amount input should show the current planned expense amount"
    end

    # Form must signal edit mode so the template-selector JS does not clear the amount
    assert_select "form[data-template-selector-edit-mode-value='true']", 1,
      "Edit form should have edit mode so amount is preserved"
  end

  test "move keeps linked spent expense in sync with new income event" do
    sign_in

    target_income_event = income_events(:two)
    budget_period = BudgetPeriod.create!(
      name: "Move Regression Period",
      start_date: Date.current.beginning_of_month,
      end_date: Date.current.end_of_month,
      account: @account
    )
    @income_event.update!(budget_period: budget_period)
    target_income_event.update!(budget_period: budget_period)

    planned_expense = PlannedExpense.create!(
      income_event: @income_event,
      category: @category,
      account: @account,
      description: "Regression spent planned expense",
      amount: 60.00,
      status: "pending_to_pay",
      financial_account: @source_account
    )

    expense = Expense.create!(
      date: Date.current,
      amount: planned_expense.amount,
      description: planned_expense.description,
      category: @category,
      budget_period: budget_period,
      income_event: @income_event,
      account: @account,
      planned_expense: planned_expense,
      financial_account: @source_account
    )

    patch move_income_event_planned_expense_path(@income_event, planned_expense), params: {
      target_income_event_id: target_income_event.id
    }

    assert_redirected_to income_event_planned_expenses_path(target_income_event)
    assert_equal target_income_event.id, planned_expense.reload.income_event_id
    assert_equal target_income_event.id, expense.reload.income_event_id
    assert_equal target_income_event.budget_period_id, expense.budget_period_id
  end
end
