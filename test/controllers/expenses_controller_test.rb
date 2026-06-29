require "test_helper"

class ExpensesControllerTest < ActionDispatch::IntegrationTest
  def setup
    @user = users(:one)
    @account = accounts(:one)
    @category = categories(:one)

    @budget_period = BudgetPeriod.create!(
      name: "March Budget",
      period_type: "monthly",
      start_date: Date.current.beginning_of_month,
      end_date: Date.current.end_of_month,
      total_amount: 5000,
      account: @account
    )

    @income_event = IncomeEvent.create!(
      description: "Salary",
      expected_date: Date.current,
      expected_amount: 3200,
      status: "pending",
      account: @account,
      budget_period: @budget_period
    )

    @asset_a = Financial::Asset.create!(
      account: @account,
      name: "Checking A",
      account_type: "checking",
      status: "active",
      opening_balance: 0
    )
    @asset_b = Financial::Asset.create!(
      account: @account,
      name: "Savings B",
      account_type: "savings",
      status: "active",
      opening_balance: 0
    )
    @liability_a = Financial::Liability.create!(
      account: @account,
      name: "Visa",
      liability_type: "credit_card",
      status: "active",
      opening_balance: 0
    )
  end

  def sign_in
    post session_path, params: {
      email_address: @user.email_address,
      password: "password"
    }
    Current.account = @account
  end

  def teardown
    Current.account = nil
    Current.session = nil
  end

  test "income event show displays quick add direct expense button" do
    sign_in

    get income_event_path(@income_event)

    assert_response :success
    assert_select "a[href='#{income_event_new_direct_expense_path(@income_event)}']", text: /Add Unplanned Expense/
  end

  test "should get quick new direct expense with defaults" do
    sign_in

    get income_event_new_direct_expense_path(@income_event)

    assert_response :success
    assert_select "h1", /Quick Add Direct Expense/
    assert_select "form[action='#{income_event_direct_expenses_path(@income_event)}']"
    assert_select "input[name='expense[date]'][value='#{Date.current}']"
    assert_select "select[name='expense[budget_period_id]'] option[selected][value='#{@budget_period.id}']"
    assert_select "p", text: /Salary/
  end

  test "should create quick direct expense for selected income event" do
    sign_in
    financial_account = Financial::Asset.create!(
      account: @account,
      name: "Checking",
      account_type: "checking",
      status: "active",
      opening_balance: 0
    )

    assert_difference("Financial::Entry.count", 1) do
      post income_event_direct_expenses_path(@income_event), params: {
        expense: {
          amount: 48.75,
          date: Date.current,
          category_id: @category.id,
          budget_period_id: @budget_period.id,
          description: "Taxi",
          source_selection: "asset:#{financial_account.id}"
        }
      }
    end

    entry = Financial::Entry.order(:created_at).last
    assert_equal @income_event.id, entry.income_event_id
    assert_equal @budget_period.id, entry.budget_period_id
    assert_equal @account.id, entry.account_id
    assert_redirected_to income_event_path(@income_event)
  end

  test "invalid quick direct expense re-renders quick form" do
    sign_in

    assert_no_difference("Expense.count") do
      post income_event_direct_expenses_path(@income_event), params: {
        expense: {
          amount: nil,
          date: Date.current,
          category_id: nil,
          budget_period_id: nil,
          description: "",
          source_selection: ""
        }
      }
    end

    assert_response :unprocessable_entity
    assert_select "h1", /Quick Add Direct Expense/
    assert_select "form[action='#{income_event_direct_expenses_path(@income_event)}']"
  end

  test "should delete expense from show page and remove linked financial entry" do
    sign_in

    financial_account = Financial::Asset.create!(
      account: @account,
      name: "Checking",
      account_type: "checking",
      status: "active",
      opening_balance: 0
    )

    planned_expense = PlannedExpense.create!(
      account: @account,
      income_event: @income_event,
      category: @category,
      description: "Taxi",
      amount: 48.75,
      status: "paid"
    )

    expense = Expense.create!(
      account: @account,
      category: @category,
      budget_period: @budget_period,
      income_event: @income_event,
      planned_expense: planned_expense,
      financial_account: financial_account,
      date: Date.current,
      amount: 48.75,
      description: "Taxi"
    )

    financial_entry = Financial::Entry.create!(
      account: @account,
      financial_account: financial_account,
      expense: expense,
      income_event: @income_event,
      category: @category,
      budget_period: @budget_period,
      entry_type: "outflow",
      entry_date: expense.date,
      amount: expense.amount,
      description: expense.description
    )

    get expense_path(expense)

    assert_response :success
    assert_select "a[href='#{expense_path(expense)}'][data-turbo-method='delete']"

    assert_difference("Expense.count", -1) do
      assert_difference("Financial::Entry.count", -1) do
        delete expense_path(expense)
      end
    end

    assert_redirected_to expenses_path
    assert_nil Expense.find_by(id: expense.id)
    assert_nil Financial::Entry.find_by(id: financial_entry.id)
    assert_equal "pending_to_pay", planned_expense.reload.status
  end

  test "updating an expense syncs linked financial entry attributes and type" do
    sign_in

    source_asset = Financial::Asset.create!(
      account: @account,
      name: "Checking",
      account_type: "checking",
      status: "active",
      opening_balance: 0
    )

    destination_liability = Financial::Liability.create!(
      account: @account,
      name: "Credit Card",
      liability_type: "credit_card",
      status: "active",
      opening_balance: 0
    )

    second_income_event = IncomeEvent.create!(
      description: "Bonus",
      expected_date: Date.current + 7.days,
      expected_amount: 1500,
      status: "pending",
      account: @account,
      budget_period: @budget_period
    )

    expense = Expense.create!(
      account: @account,
      category: @category,
      budget_period: @budget_period,
      income_event: @income_event,
      financial_account: source_asset,
      date: Date.current,
      amount: 100,
      description: "Initial expense"
    )

    entry = Financial::Entry.create!(
      account: @account,
      financial_account: source_asset,
      expense: expense,
      income_event: @income_event,
      category: @category,
      budget_period: @budget_period,
      entry_type: "outflow",
      entry_date: expense.date,
      amount: expense.amount,
      description: expense.description
    )

    patch expense_path(entry), params: {
      financial_entry: {
        date: Date.current + 1.day,
        amount: 275.40,
        description: "Updated payment",
        category_id: @category.id,
        budget_period_id: @budget_period.id,
        income_event_id: second_income_event.id,
        source_selection: "asset:#{source_asset.id}",
        destination_selection: "liability:#{destination_liability.id}"
      }
    }

    assert_redirected_to expense_path(entry)
    entry.reload

    assert_equal 275.40, entry.amount.to_f
    assert_equal Date.current + 1.day, entry.entry_date
    assert_equal "Updated payment", entry.description
    assert_equal second_income_event.id, entry.income_event_id
    assert_equal "liability_payment", entry.entry_type
    assert_equal source_asset.id, entry.financial_account_id
    assert_equal destination_liability.id, entry.financial_liability_id
  end

  test "index filters expenses by asset account and excludes transfers" do
    sign_in

    source_match = Financial::Entry.create!(
      account: @account,
      category: @category,
      budget_period: @budget_period,
      income_event: @income_event,
      financial_account: @asset_a,
      entry_date: Date.current,
      entry_type: "outflow",
      amount: 10,
      description: "source match"
    )
    counterparty_match = Financial::Entry.create!(
      account: @account,
      category: @category,
      budget_period: @budget_period,
      income_event: @income_event,
      financial_account: @asset_b,
      counterparty_financial_account: @asset_a,
      entry_date: Date.current,
      entry_type: "transfer",
      amount: 20,
      description: "counterparty match"
    )
    non_match = Financial::Entry.create!(
      account: @account,
      category: @category,
      budget_period: @budget_period,
      income_event: @income_event,
      financial_account: @asset_b,
      entry_date: Date.current,
      entry_type: "outflow",
      amount: 30,
      description: "non match"
    )

    get expenses_path, params: { account_ref: "asset:#{@asset_a.id}" }

    assert_response :success
    assert_select "option[value='asset:#{@asset_a.id}'][selected]"
    assert_includes response.body, source_match.description
    assert_not_includes response.body, counterparty_match.description
    assert_not_includes response.body, non_match.description
  end

  test "index filters expenses by liability account and excludes liability payments" do
    sign_in

    source_match = Financial::Entry.create!(
      account: @account,
      category: @category,
      budget_period: @budget_period,
      income_event: @income_event,
      financial_liability: @liability_a,
      entry_date: Date.current,
      entry_type: "liability_charge",
      amount: 15,
      description: "liability source match"
    )
    counterparty_match = Financial::Entry.create!(
      account: @account,
      category: @category,
      budget_period: @budget_period,
      income_event: @income_event,
      financial_account: @asset_a,
      financial_liability: @liability_a,
      entry_date: Date.current,
      entry_type: "liability_payment",
      amount: 25,
      description: "liability counterparty match"
    )
    non_match = Financial::Entry.create!(
      account: @account,
      category: @category,
      budget_period: @budget_period,
      income_event: @income_event,
      financial_account: @asset_a,
      entry_date: Date.current,
      entry_type: "outflow",
      amount: 35,
      description: "liability non match"
    )

    get expenses_path, params: { account_ref: "liability:#{@liability_a.id}" }

    assert_response :success
    assert_includes response.body, source_match.description
    assert_not_includes response.body, counterparty_match.description
    assert_not_includes response.body, non_match.description
  end

  test "index composes account filter with date category and description filters" do
    sign_in

    match = Financial::Entry.create!(
      account: @account,
      category: @category,
      budget_period: @budget_period,
      income_event: @income_event,
      financial_account: @asset_a,
      entry_date: Date.current,
      entry_type: "outflow",
      amount: 22,
      description: "target lunch"
    )
    wrong_description = Financial::Entry.create!(
      account: @account,
      category: @category,
      budget_period: @budget_period,
      income_event: @income_event,
      financial_account: @asset_a,
      entry_date: Date.current,
      entry_type: "outflow",
      amount: 23,
      description: "other text"
    )
    wrong_account = Financial::Entry.create!(
      account: @account,
      category: @category,
      budget_period: @budget_period,
      income_event: @income_event,
      financial_account: @asset_b,
      entry_date: Date.current,
      entry_type: "outflow",
      amount: 24,
      description: "target dinner"
    )

    get expenses_path, params: {
      account_ref: "asset:#{@asset_a.id}",
      date_from: Date.current,
      date_to: Date.current,
      category_id: @category.id,
      q: "target"
    }

    assert_response :success
    assert_includes response.body, match.description
    assert_not_includes response.body, wrong_description.description
    assert_not_includes response.body, wrong_account.description
  end

  test "index ignores malformed account_ref" do
    sign_in

    first = Financial::Entry.create!(
      account: @account,
      category: @category,
      budget_period: @budget_period,
      income_event: @income_event,
      financial_account: @asset_a,
      entry_date: Date.current,
      entry_type: "outflow",
      amount: 11,
      description: "first expense"
    )
    second = Financial::Entry.create!(
      account: @account,
      category: @category,
      budget_period: @budget_period,
      income_event: @income_event,
      financial_account: @asset_b,
      entry_date: Date.current,
      entry_type: "outflow",
      amount: 12,
      description: "second expense"
    )

    get expenses_path, params: { account_ref: "oops" }

    assert_response :success
    assert_includes response.body, first.description
    assert_includes response.body, second.description
  end
end
