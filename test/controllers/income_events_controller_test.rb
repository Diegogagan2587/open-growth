require "test_helper"

class IncomeEventsControllerTest < ActionDispatch::IntegrationTest
  def setup
    @user = users(:one)
    @account = accounts(:one)
    Current.account = @account

    @loan_liability = Financial::Liability.create!(
      account: @account,
      name: "Loan Origin",
      liability_type: "personal_credit",
      status: "active",
      opening_balance: 0
    )

    @destination_asset = Financial::Asset.create!(
      account: @account,
      name: "Checking",
      account_type: "checking",
      status: "active",
      opening_balance: 0
    )

    Category.create!(name: "Debt", account: @account)

    @loan_income_event = IncomeEvent.create!(
      account: @account,
      description: "Loan Income",
      expected_date: Date.current,
      expected_amount: 1000,
      income_type: "loan",
      loan_amount: 1000,
      number_of_payments: 2,
      payment_frequency: "monthly",
      payment_amount: 550,
      status: "pending",
      loan_liability: @loan_liability,
      destination_selection: "asset:#{@destination_asset.id}"
    )
  end

  def teardown
    Current.account = nil
    Current.session = nil
  end

  def sign_in
    post session_path, params: {
      email_address: @user.email_address,
      password: "password"
    }
    Current.account = @account
  end

  test "index eagerly loads budget periods" do
    sign_in
    budget_period = @account.budget_periods.create!(
      name: "July",
      period_type: "monthly",
      start_date: Date.current.beginning_of_month,
      end_date: Date.current.end_of_month
    )
    2.times do |index|
      IncomeEvent.create!(
        account: @account,
        budget_period: budget_period,
        description: "Salary #{index}",
        expected_date: Date.current + index.days,
        expected_amount: 2000,
        status: "pending"
      )
    end

    get income_events_path

    assert_response :success
  end

  test "show renders entry backed direct expenses without category" do
    sign_in
    income_event = IncomeEvent.create!(
      account: @account,
      description: "Salary",
      expected_date: Date.current,
      expected_amount: 2000,
      status: "pending"
    )
    entry = Financial::Entry.new(
      account: @account,
      income_event: income_event,
      financial_account: @destination_asset,
      entry_type: "outflow",
      entry_date: Date.current,
      amount: 25,
      description: "Legacy uncategorized direct expense"
    )
    entry.save!(validate: false)

    get income_event_path(income_event)

    assert_response :success
    assert_includes response.body, "Legacy uncategorized direct expense"
    assert_includes response.body, I18n.t("expenses.index.unassigned")
  end

  test "show uses planned transaction labels and actions" do
    sign_in

    get income_event_path(@loan_income_event)

    assert_response :success
    assert_select "h2", "Planned Transactions"
    assert_select "a", "Plan Transaction"
    assert_select "a", "View Plan"
  end

  test "show uses a padded shell and a low-chrome income summary" do
    sign_in

    get income_event_path(@loan_income_event)

    assert_response :success
    assert_select "main > div[class*='p-4'][class*='sm:p-6']", count: 1
    assert_select "main > div > p[style='color: green']", count: 0
    assert_select "section[aria-labelledby='income-event-title'][class*='border-b']", count: 1
    assert_select "section[aria-labelledby='income-event-title'].rounded-2xl", count: 0
    assert_select "#income-event-metrics[class*='divide-y']", count: 1
    assert_select "#income-event-metrics > div.rounded-xl", count: 0
  end

  test "show separates planned expenses from movements with independent totals" do
    sign_in
    income_event = IncomeEvent.create!(
      account: @account,
      description: "Mixed plan salary",
      expected_date: Date.current,
      expected_amount: 1000,
      status: "pending"
    )
    category = Category.for_account(@account).first
    source = Financial::Asset.create!(
      account: @account,
      name: "Mixed plan source",
      account_type: "checking",
      status: "active",
      opening_balance: 500
    )
    destination = Financial::Asset.create!(
      account: @account,
      name: "Mixed plan destination",
      account_type: "savings",
      status: "active",
      opening_balance: 0
    )
    PlannedExpense.create!(income_event: income_event, category: category, description: "Food expense", amount: 100, status: "pending_to_pay", financial_account: source)
    PlannedExpense.create!(income_event: income_event, category: category, description: "Savings transfer", amount: 200, status: "pending_to_pay", financial_account: source, counterparty_financial_account: destination)

    get income_event_path(income_event)

    assert_response :success
    assert_select "#planned-expenses" do
      assert_select "h4", "Food expense"
      assert_select "h4", text: "Savings transfer", count: 0
      assert_select "p", text: /10.0% of income/
      assert_select "p", text: /Total.*\$100\.00/
    end
    assert_select "#planned-movements" do
      assert_select "h4", "Savings transfer"
      assert_select "h4", text: "Food expense", count: 0
      assert_select "p", "Transfer"
      assert_select "p", "Does not affect budget"
      assert_select "p", text: /Transfer from Mixed plan source to Mixed plan destination/
      assert_select "p", text: /Total.*\$200\.00/
    end
    assert_equal 100.to_d, income_event.reload.total_planned
    assert_equal 900.to_d, income_event.remaining_budget
  end

  test "mark as received creates loan disbursement entry" do
    sign_in

    assert_difference("Financial::Entry.where(entry_type: 'loan_disbursement', income_event_id: #{@loan_income_event.id}).count", 1) do
      patch receive_income_event_path(@loan_income_event), params: {
        income_event: {
          received_date: Date.current,
          received_amount: 1000
        }
      }
    end

    assert_redirected_to income_event_path(@loan_income_event)

    entry = Financial::Entry.where(entry_type: "loan_disbursement", income_event_id: @loan_income_event.id).first
    assert_not_nil entry
    assert_equal @loan_liability.id, entry.financial_liability_id
    assert_equal @destination_asset.id, entry.financial_account_id
    assert_equal 1000.to_d, entry.amount.to_d
  end

  test "regular income persists destination and syncs inflow on receive" do
    sign_in
    destination_asset = Financial::Asset.create!(
      account: @account,
      name: "Payroll",
      account_type: "checking",
      status: "active",
      opening_balance: 0
    )

    assert_difference("IncomeEvent.count", 1) do
      post income_events_path, params: {
        income_event: {
          description: "Salary",
          expected_date: Date.current,
          expected_amount: 2000,
          status: "pending",
          income_type: "regular",
          destination_selection: "asset:#{destination_asset.id}"
        }
      }
    end

    income_event = IncomeEvent.order(:created_at).last
    assert_equal destination_asset.id, income_event.regular_income_destination_asset_id
    assert_nil Financial::Entry.find_by(income_event: income_event, entry_type: "inflow")

    patch receive_income_event_path(income_event), params: {
      income_event: {
        received_date: Date.current,
        received_amount: 2100
      }
    }

    income_event.reload
    entry = Financial::Entry.find_by(income_event: income_event, entry_type: "inflow")
    assert_not_nil entry
    assert_equal 2100.to_d, entry.amount
    assert_equal destination_asset.id, entry.financial_account_id
  end
end
