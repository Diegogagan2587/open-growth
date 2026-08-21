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

  test "legacy index redirects to financial plans" do
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

    assert_redirected_to finance_plans_path
  end

  test "finance plan facade resolves the same record id" do
    sign_in

    get finance_plan_path(@loan_income_event)

    assert_response :success
    assert_select "body", text: /#{Regexp.escape(@loan_income_event.description)}/
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
    entry = Financial::Transaction.new(
      account: @account,
      plan: Financial::Plan.find(income_event.id),
      source_account: @destination_asset,
      transaction_type: "expense",
      transaction_date: Date.current,
      amount: 25,
      description: "Legacy uncategorized direct expense"
    )
    entry.save!(validate: false)

    get finance_plan_path(income_event)

    assert_response :success
    assert_includes response.body, "Legacy uncategorized direct expense"
    assert_includes response.body, "Uncategorized"
  end

  test "show uses planned transaction labels and actions" do
    sign_in

    get finance_plan_path(@loan_income_event)

    assert_response :success
    assert_select "h2", "Planned transactions"
    assert_select "summary", "Add planned transaction"
  end

  test "show uses a padded shell and a low-chrome income summary" do
    sign_in

    get finance_plan_path(@loan_income_event)

    assert_response :success
    assert_select "main section[class*='p-6'][class*='sm:p-8']", count: 1
    assert_select "main > div > p[style='color: green']", count: 0
    assert_select "h1", text: @loan_income_event.description, count: 1
    assert_select "section[aria-labelledby='plan-results-title']", count: 1
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

    get finance_plan_path(income_event)

    assert_response :success
    assert_select "section[aria-labelledby='planned-transactions-title'] article", count: 2
    assert_select "section[aria-labelledby='planned-transactions-title']", text: /Food expense/
    assert_select "section[aria-labelledby='planned-transactions-title']", text: /Savings transfer/
    running_balances = css_select("section[aria-labelledby='planned-transactions-title'] article p.text-xs").map { |node| node.text.strip }
    assert_equal 2, running_balances.size
    assert_equal 1, running_balances.uniq.size, "budget-neutral transfer should not change the running balance"
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
    source = Financial::FundingSource.find_by!(legacy_income_event_id: income_event.id)
    entry = source.receipt_transaction
    assert_not_nil entry
    assert_equal 2100.to_d, entry.amount
    assert_equal destination_asset.id, entry.destination_account_id
  end
end
