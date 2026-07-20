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

    @liability = Financial::Liability.create!(
      name: "Controller Credit Card",
      account: @account,
      liability_type: "credit_card",
      status: "active",
      opening_balance: 300.00
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
    assert_select "h1", "Plan Transaction"
    assert_select "form"
    assert_select "select[name='planned_expense[source_selection]']"
    assert_select "select[name='planned_expense[destination_selection]']", 0
    assert_select "select[name='planned_expense[income_event_id]']", 0
    assert_select "select[name='planned_expense[status]']", 0
    assert_select "input[name='planned_expense[position]']", 0
    expense_path = new_income_event_planned_expense_path(@income_event, kind: "expense")
    transfer_path = new_income_event_planned_expense_path(@income_event, kind: "transfer")
    assert_select "a[href='#{expense_path}'][aria-current='page']" do
      assert_select "span", "Expense"
    end
    assert_select "a[href='#{transfer_path}']" do
      assert_select "span", "Transfer"
    end
  end

  test "new transfer renders transfer-only fields and preserves the selected tab" do
    sign_in
    get new_income_event_planned_expense_path(@income_event, kind: "transfer")
    assert_response :success
    assert_select "h2", "Plan a transfer"
    assert_select "a[aria-current='page'] span", "Transfer"
    assert_select "select[name='planned_expense[source_selection]'] option[value^='liability:']", 0
    assert_select "select[name='planned_expense[destination_selection]'] option[value='liability:#{@liability.id}']"
    assert_select "select[name='planned_expense[category_id]']", 0
    assert_select "select[name='planned_expense[expense_template_id]']", 0
  end

  test "expense template is presented as a compact optional dropdown" do
    sign_in
    template = ExpenseTemplate.create!(
      account: @account,
      category: @category,
      name: "Monthly rent",
      description: "Rent",
      total_amount: 900,
      frequency: "monthly"
    )
    get new_income_event_planned_expense_path(@income_event)
    assert_response :success
    assert_select "select[name='planned_expense[expense_template_id]'] option[value='#{template.id}']", "Monthly rent"
    assert_select "form[data-controller='template-selector']"
    assert_includes response.body, "Rent"
    assert_select "select[data-template-selector-target='categorySelect']"
    assert_select "input[data-template-selector-target='descriptionField']"
    assert_select "input[data-template-selector-target='amountField']"
    assert_select "input[name='use_template']", 0
    assert_select "h3", text: /Template Selection/, count: 0
  end

  test "should create planned expense" do
    sign_in
    assert_difference("PlannedExpense.count") do
      post income_event_planned_expenses_path(@income_event), params: {
        planned_expense: {
          category_id: @category.id,
          description: "Test Expense",
          amount: 100.00,
          status: "spent",
          income_event_id: income_events(:two).id,
          position: 99,
          source_selection: "asset:#{@source_account.id}"
        }
      }
    end

    assert_redirected_to income_event_planned_expenses_path(@income_event)
    planned_expense = PlannedExpense.order(:created_at).last
    assert_equal @income_event, planned_expense.income_event
    assert_equal "pending_to_pay", planned_expense.status
    assert_not_equal 99, planned_expense.position
  end

  test "index separates budget expenses from budget-neutral movements" do
    sign_in
    @income_event.planned_expenses.delete_all
    expense = PlannedExpense.create!(
      income_event: @income_event,
      category: @category,
      account: @account,
      description: "Groceries plan",
      amount: 90,
      status: "pending_to_pay",
      financial_account: @source_account
    )
    transfer = PlannedExpense.create!(
      income_event: @income_event,
      category: @category,
      account: @account,
      description: "Savings movement",
      amount: 125,
      status: "pending_to_pay",
      financial_account: @source_account,
      counterparty_financial_account: @destination_account
    )
    payment = PlannedExpense.create!(
      income_event: @income_event,
      account: @account,
      description: "Card movement",
      amount: 80,
      status: "pending_to_pay",
      financial_account: @source_account,
      financial_liability: @liability
    )

    get income_event_planned_expenses_path(@income_event)

    assert_response :success
    assert_select "h1", "Planned Transactions"
    assert_select "a", "Plan Transaction"
    assert_select "#planned-expenses" do
      assert_select "h2", text: /Planned Expenses/
      assert_select "h3", expense.description
      assert_select "h3", text: transfer.description, count: 0
      assert_select "h3", text: payment.description, count: 0
      assert_select "div", text: /Available after this expense:/
    end
    assert_select "#planned-movements" do
      assert_select "h2", text: /Planned Movements/
      assert_select "h3", text: expense.description, count: 0
      assert_select "h3", transfer.description
      assert_select "h3", payment.description
      assert_select "span", "Transfer"
      assert_select "span", "Card payment"
      assert_select "span", text: "Does not affect budget", count: 2
      assert_select "div", text: /Available after this expense:/, count: 0
    end
    assert_equal 90.to_d, @income_event.reload.total_planned
  end

  test "index renders a single empty state when no transactions are planned" do
    sign_in
    @income_event.planned_expenses.delete_all

    get income_event_planned_expenses_path(@income_event)

    assert_response :success
    assert_select "h2", "No planned transactions"
    assert_select "#planned-expenses", count: 0
    assert_select "#planned-movements", count: 0
  end

  test "index renders compact empty states when only one transaction group exists" do
    sign_in
    @income_event.planned_expenses.delete_all
    PlannedExpense.create!(
      income_event: @income_event,
      category: @category,
      account: @account,
      description: "Expense only",
      amount: 45,
      status: "pending_to_pay"
    )

    get income_event_planned_expenses_path(@income_event)

    assert_response :success
    assert_select "#planned-expenses h3", "Expense only"
    assert_select "#planned-movements", text: /No planned movements yet/

    @income_event.planned_expenses.delete_all
    PlannedExpense.create!(
      income_event: @income_event,
      account: @account,
      description: "Movement only",
      amount: 60,
      status: "pending_to_pay",
      financial_account: @source_account,
      counterparty_financial_account: @destination_account
    )

    get income_event_planned_expenses_path(@income_event)

    assert_response :success
    assert_select "#planned-expenses", text: /No planned expenses yet/
    assert_select "#planned-movements h3", "Movement only"
  end

  test "creates asset transfer without category and does not consume budget" do
    sign_in
    total_planned = @income_event.total_planned

    assert_difference("PlannedExpense.count", 1) do
      post income_event_planned_expenses_path(@income_event, kind: "transfer"), params: {
        planned_expense: {
          description: "Move to savings",
          amount: 125,
          source_selection: "asset:#{@source_account.id}",
          destination_selection: "asset:#{@destination_account.id}"
        }
      }
    end

    planned_expense = PlannedExpense.order(:created_at).last
    assert_nil planned_expense.category
    assert planned_expense.transfer?
    assert_equal total_planned, @income_event.reload.total_planned
  end

  test "creates card payment without category and does not consume budget" do
    sign_in
    total_planned = @income_event.total_planned

    assert_difference("PlannedExpense.count", 1) do
      post income_event_planned_expenses_path(@income_event, kind: "transfer"), params: {
        planned_expense: {
          description: "Pay card",
          amount: 80,
          source_selection: "asset:#{@source_account.id}",
          destination_selection: "liability:#{@liability.id}"
        }
      }
    end

    planned_expense = PlannedExpense.order(:created_at).last
    assert_nil planned_expense.category
    assert planned_expense.debt_payment?
    assert_equal total_planned, @income_event.reload.total_planned
  end

  test "rejects a transfer with the same source and destination" do
    sign_in
    assert_no_difference("PlannedExpense.count") do
      post income_event_planned_expenses_path(@income_event, kind: "transfer"), params: {
        planned_expense: {
          description: "Invalid movement",
          amount: 20,
          source_selection: "asset:#{@source_account.id}",
          destination_selection: "asset:#{@source_account.id}"
        }
      }
    end

    assert_response :unprocessable_entity
    assert_select "a[aria-current='page'] span", "Transfer"
    assert_select "input[name='planned_expense[description]'][value='Invalid movement']"
    assert_select "select[name='planned_expense[source_selection]'] option[selected][value='asset:#{@source_account.id}']"
    assert_select "select[name='planned_expense[destination_selection]'] option[selected][value='asset:#{@source_account.id}']"
  end

  test "rejects transfer accounts from another account" do
    sign_in
    foreign_asset = Financial::Asset.create!(
      name: "Foreign asset",
      account: accounts(:two),
      account_type: "checking",
      status: "active",
      opening_balance: 0
    )

    assert_no_difference("PlannedExpense.count") do
      post income_event_planned_expenses_path(@income_event, kind: "transfer"), params: {
        planned_expense: {
          description: "Invalid cross-account movement",
          amount: 20,
          source_selection: "asset:#{foreign_asset.id}",
          destination_selection: "asset:#{@destination_account.id}"
        }
      }
    end

    assert_response :unprocessable_entity
    assert_select "a[aria-current='page'] span", "Transfer"

    assert_no_difference("PlannedExpense.count") do
      post income_event_planned_expenses_path(@income_event, kind: "transfer"), params: {
        planned_expense: {
          description: "Invalid cross-account destination",
          amount: 20,
          source_selection: "asset:#{@source_account.id}",
          destination_selection: "asset:#{foreign_asset.id}"
        }
      }
    end

    assert_response :unprocessable_entity
    assert_select "a[aria-current='page'] span", "Transfer"
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

  test "updating a finalized planned expense cannot rewrite its actual entry" do
    sign_in
    historical_date = Date.new(2025, 1, 20)
    planned_expense = PlannedExpense.create!(
      income_event: @income_event,
      category: @category,
      account: @account,
      description: "Historical expense",
      amount: 90.00,
      status: "paid",
      financial_account: @source_account,
      applied_on: nil
    )
    entry = Financial::Entry.create!(
      account: @account,
      planned_expense: planned_expense,
      income_event: @income_event,
      category: @category,
      budget_period: @budget_period,
      description: planned_expense.description,
      amount: planned_expense.amount,
      entry_type: "outflow",
      entry_date: historical_date,
      financial_account: @source_account
    )

    assert_no_difference("Financial::Entry.count") do
      patch income_event_planned_expense_path(@income_event, planned_expense), params: {
        planned_expense: {
          category_id: "",
          description: planned_expense.description,
          amount: 125.00,
          status: "paid",
          source_selection: "asset:#{@source_account.id}",
          destination_selection: "asset:#{@destination_account.id}"
        }
      }
    end

    assert_response :unprocessable_entity
    assert_equal entry.id, planned_expense.reload.financial_entry.id
    assert_equal "outflow", entry.reload.entry_type
    assert_equal 90.to_d, entry.amount
    assert_equal @source_account.id, entry.financial_account_id
    assert_nil entry.counterparty_financial_account_id
    assert_equal historical_date, entry.entry_date
    assert_equal 90.to_d, planned_expense.amount
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
          description: "Needs a category",
          amount: 30,
          status: "spent"
        }
      }
    end

    assert_response :unprocessable_entity
    assert_select "a[aria-current='page'] span", "Expense"
    assert_select "input[name='planned_expense[description]'][value='Needs a category']"
    assert_select "input[name='planned_expense[amount]'][value='30.0']"
    assert_select "select[name='planned_expense[income_event_id]']", 0
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

  test "move changes only the planning assignment and leaves legacy actual history intact" do
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
    assert_equal @income_event.id, expense.reload.income_event_id
    assert_equal budget_period.id, expense.budget_period_id
  end
end
