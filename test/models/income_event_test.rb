require "test_helper"

class IncomeEventTest < ActiveSupport::TestCase
  def setup
    @account = Account.create!(name: "Test Account")
    Current.account = @account

    @budget_period = BudgetPeriod.create!(
      name: "Test Period",
      start_date: Date.new(2025, 1, 1),
      end_date: Date.new(2025, 12, 31),
      account: @account
    )
  end

  def teardown
    Current.account = nil
  end

  test "previous_income_event returns nil for first event in budget period" do
    event = IncomeEvent.create!(
      budget_period: @budget_period,
      description: "First Event",
      expected_date: Date.new(2025, 1, 15),
      expected_amount: 1000.00,
      status: "pending",
      account: @account
    )

    assert_nil event.previous_income_event
    assert_equal 0.0, event.previous_balance
  end

  test "loan requires origin liability and one destination" do
    loan = IncomeEvent.new(
      account: @account,
      description: "Loan",
      expected_date: Date.current,
      expected_amount: 1000,
      income_type: "loan",
      loan_amount: 1000,
      number_of_payments: 2,
      payment_frequency: "monthly",
      payment_amount: 550,
      status: "pending"
    )

    assert_not loan.valid?
    assert_includes loan.errors[:loan_liability], "must be selected"
    assert_includes loan.errors[:destination_selection], "must select exactly one destination account"
  end

  test "previous_income_event finds correct previous event by expected_date" do
    event1 = IncomeEvent.create!(
      budget_period: @budget_period,
      description: "Event 1",
      expected_date: Date.new(2025, 1, 15),
      expected_amount: 1000.00,
      status: "pending",
      account: @account
    )

    event2 = IncomeEvent.create!(
      budget_period: @budget_period,
      description: "Event 2",
      expected_date: Date.new(2025, 2, 15),
      expected_amount: 2000.00,
      status: "pending",
      account: @account
    )

    assert_equal event1, event2.previous_income_event
    assert_nil event1.previous_income_event
  end

  test "previous_income_event uses received_date when present for ordering" do
    # Event 1: expected Jan 15, received Jan 12 (received before expected)
    event1 = IncomeEvent.create!(
      budget_period: @budget_period,
      description: "Event 1",
      expected_date: Date.new(2025, 1, 15),
      expected_amount: 1000.00,
      received_date: Date.new(2025, 1, 12),
      received_amount: 1000.00,
      status: "received",
      account: @account
    )

    # Event 2: expected Jan 18, not received yet
    event2 = IncomeEvent.create!(
      budget_period: @budget_period,
      description: "Event 2",
      expected_date: Date.new(2025, 1, 18),
      expected_amount: 1500.00,
      status: "pending",
      account: @account
    )

    # Event 3: expected Jan 25, not received yet
    event3 = IncomeEvent.create!(
      budget_period: @budget_period,
      description: "Event 3",
      expected_date: Date.new(2025, 1, 25),
      expected_amount: 2000.00,
      status: "pending",
      account: @account
    )

    # Event 2 should have event1 as previous (received Jan 12 comes before expected Jan 18)
    assert_equal event1, event2.previous_income_event

    # Event 3 should have event2 as previous (expected Jan 18 comes before expected Jan 25)
    assert_equal event2, event3.previous_income_event
  end

  test "previous_income_event handles events on same date using id as tiebreaker" do
    event1 = IncomeEvent.create!(
      budget_period: @budget_period,
      description: "Event 1",
      expected_date: Date.new(2025, 1, 15),
      expected_amount: 1000.00,
      status: "pending",
      account: @account
    )

    event2 = IncomeEvent.create!(
      budget_period: @budget_period,
      description: "Event 2",
      expected_date: Date.new(2025, 1, 15),
      expected_amount: 2000.00,
      status: "pending",
      account: @account
    )

    event3 = IncomeEvent.create!(
      budget_period: @budget_period,
      description: "Event 3",
      expected_date: Date.new(2025, 1, 15),
      expected_amount: 3000.00,
      status: "pending",
      account: @account
    )

    # All events have same expected_date, so previous should be based on id
    assert_equal event2, event3.previous_income_event
    assert_equal event1, event2.previous_income_event
    assert_nil event1.previous_income_event
  end

  test "previous_income_event only considers events in same budget period" do
    other_period = BudgetPeriod.create!(
      name: "Other Period",
      start_date: Date.new(2026, 1, 1),
      end_date: Date.new(2026, 12, 31),
      account: @account
    )

    event1 = IncomeEvent.create!(
      budget_period: @budget_period,
      description: "Event 1",
      expected_date: Date.new(2025, 1, 15),
      expected_amount: 1000.00,
      status: "pending",
      account: @account
    )

    event2 = IncomeEvent.create!(
      budget_period: other_period,
      description: "Event 2",
      expected_date: Date.new(2025, 1, 10), # Earlier date but different period
      expected_amount: 2000.00,
      status: "pending",
      account: @account
    )

    event3 = IncomeEvent.create!(
      budget_period: @budget_period,
      description: "Event 3",
      expected_date: Date.new(2025, 2, 15),
      expected_amount: 3000.00,
      status: "pending",
      account: @account
    )

    # Event 3 should have event1 as previous, not event2 (different period)
    assert_equal event1, event3.previous_income_event
    assert_nil event2.previous_income_event
  end

  test "previous_balance returns remaining_budget of previous event" do
    event1 = IncomeEvent.create!(
      budget_period: @budget_period,
      description: "Event 1",
      expected_date: Date.new(2025, 1, 15),
      expected_amount: 1000.00,
      status: "pending",
      account: @account
    )

    # Create planned expense to create a negative balance
    category = Category.create!(name: "Test Category", account: @account)
    PlannedExpense.create!(
      income_event: event1,
      category: category,
      description: "Expense",
      amount: 1500.00,
      status: "pending_to_pay",
      account: @account
    )

    event2 = IncomeEvent.create!(
      budget_period: @budget_period,
      description: "Event 2",
      expected_date: Date.new(2025, 2, 15),
      expected_amount: 2000.00,
      status: "pending",
      account: @account
    )

    # Event1 has remaining_budget of 1000 - 1500 = -500
    assert_equal(-500.0, event1.remaining_budget)
    # Event2 should have previous_balance of -500 (event1's remaining_budget)
    assert_equal(-500.0, event2.previous_balance)
  end

  test "previous_balance uses effective_remaining_budget for cumulative carryover" do
    event1 = IncomeEvent.create!(
      budget_period: @budget_period,
      description: "Event 1",
      expected_date: Date.new(2025, 1, 15),
      expected_amount: 1000.00,
      status: "pending",
      account: @account
    )

    category = Category.create!(name: "Test Category", account: @account)
    PlannedExpense.create!(
      income_event: event1,
      category: category,
      description: "Expense",
      amount: 1500.00,
      status: "pending_to_pay",
      account: @account
    )

    # Event1: remaining_budget = -500, effective_remaining_budget = -500 (no previous)
    assert_equal(-500.0, event1.remaining_budget)
    assert_equal(-500.0, event1.effective_remaining_budget)

    event2 = IncomeEvent.create!(
      budget_period: @budget_period,
      description: "Event 2",
      expected_date: Date.new(2025, 2, 15),
      expected_amount: 2000.00,
      status: "pending",
      account: @account
    )

    PlannedExpense.create!(
      income_event: event2,
      category: category,
      description: "Expense 2",
      amount: 500.00,
      status: "pending_to_pay",
      account: @account
    )

    # Event2: remaining_budget = 2000 - 500 = 1500
    # previous_balance = event1.effective_remaining_budget = -500
    # effective_remaining_budget = 1500 + (-500) = 1000
    assert_equal(1500.0, event2.remaining_budget)
    assert_equal(-500.0, event2.previous_balance)
    assert_equal(1000.0, event2.effective_remaining_budget)

    event3 = IncomeEvent.create!(
      budget_period: @budget_period,
      description: "Event 3",
      expected_date: Date.new(2025, 3, 15),
      expected_amount: 3000.00,
      status: "pending",
      account: @account
    )

    # Event3: remaining_budget = 3000 (no expenses)
    # previous_balance = event2.effective_remaining_budget = 1000
    # effective_remaining_budget = 3000 + 1000 = 4000
    assert_equal(3000.0, event3.remaining_budget)
    assert_equal(1000.0, event3.previous_balance)
    assert_equal(4000.0, event3.effective_remaining_budget)
  end

  test "receiving funding creates an inflow and later expectation edits do not rewrite it" do
    destination_asset = Financial::Asset.create!(
      account: @account,
      name: "Checking",
      account_type: "checking",
      status: "active",
      opening_balance: 0
    )

    income = IncomeEvent.create!(
      account: @account,
      description: "Salary",
      expected_date: Date.current,
      expected_amount: 1000,
      received_date: Date.current,
      received_amount: 1000,
      status: "received",
      destination_selection: "asset:#{destination_asset.id}"
    )

    source = income.ensure_primary_funding_source!
    result = Financial::FundingSources::ReceiveService.call(funding_source: source)
    entry = result.entry
    assert_not_nil entry
    assert_equal destination_asset.id, entry.financial_account_id

    assert_no_difference("Financial::Entry.where(income_event_id: #{income.id}, entry_type: 'inflow').count") do
      income.update!(received_amount: 1200)
    end

    assert_equal 1000.to_d, entry.reload.amount
  end

  test "changing planning status does not delete an actual liability receipt" do
    destination_liability = Financial::Liability.create!(
      account: @account,
      name: "Card",
      liability_type: "credit_card",
      status: "active",
      opening_balance: 500
    )

    income = IncomeEvent.create!(
      account: @account,
      description: "Debt payoff",
      expected_date: Date.current,
      expected_amount: 200,
      received_date: Date.current,
      received_amount: 200,
      status: "received",
      destination_selection: "liability:#{destination_liability.id}"
    )

    source = income.ensure_primary_funding_source!
    entry = Financial::FundingSources::ReceiveService.call(funding_source: source).entry
    assert_not_nil entry
    assert_equal destination_liability.id, entry.counterparty_financial_liability_id
    assert_equal 300.to_d, destination_liability.current_balance

    income.update!(status: "pending")
    assert Financial::Entry.exists?(entry.id)
  end

  test "previous_balance handles events across year boundaries" do
    event1 = IncomeEvent.create!(
      budget_period: @budget_period,
      description: "Event 2025",
      expected_date: Date.new(2025, 12, 30),
      expected_amount: 1000.00,
      received_date: Date.new(2025, 12, 30),
      received_amount: 1000.00,
      status: "received",
      account: @account
    )

    event2 = IncomeEvent.create!(
      budget_period: @budget_period,
      description: "Event 2026",
      expected_date: Date.new(2026, 1, 15),
      expected_amount: 2000.00,
      status: "pending",
      account: @account
    )

    # Event2 should find event1 as previous even though it's from previous year
    assert_equal event1, event2.previous_income_event
    assert_equal event1.remaining_budget, event2.previous_balance
  end

  test "previous_balance handles mixed received and pending events correctly" do
    # Create events in chronological order
    event1 = IncomeEvent.create!(
      budget_period: @budget_period,
      description: "Received Event",
      expected_date: Date.new(2025, 1, 10),
      expected_amount: 1000.00,
      received_date: Date.new(2025, 1, 12),
      received_amount: 1000.00,
      status: "received",
      account: @account
    )

    event2 = IncomeEvent.create!(
      budget_period: @budget_period,
      description: "Pending Event",
      expected_date: Date.new(2025, 1, 15),
      expected_amount: 2000.00,
      status: "pending",
      account: @account
    )

    event3 = IncomeEvent.create!(
      budget_period: @budget_period,
      description: "Another Received",
      expected_date: Date.new(2025, 1, 20),
      expected_amount: 3000.00,
      received_date: Date.new(2025, 1, 18), # Received before expected
      received_amount: 3000.00,
      status: "received",
      account: @account
    )

    # Event2 should have event1 as previous (received Jan 12 < expected Jan 15)
    assert_equal event1, event2.previous_income_event

    # Event3 should have event2 as previous (expected Jan 15 < received Jan 18)
    assert_equal event2, event3.previous_income_event
  end

  test "effective_remaining_budget correctly calculates with negative previous balance" do
    event1 = IncomeEvent.create!(
      budget_period: @budget_period,
      description: "Event with Deficit",
      expected_date: Date.new(2025, 1, 15),
      expected_amount: 1000.00,
      status: "pending",
      account: @account
    )

    category = Category.create!(name: "Test Category", account: @account)
    PlannedExpense.create!(
      income_event: event1,
      category: category,
      description: "Large Expense",
      amount: 2000.00,
      status: "pending_to_pay",
      account: @account
    )

    # Event1 has -1000 remaining
    assert_equal(-1000.0, event1.remaining_budget)
    assert_equal(-1000.0, event1.effective_remaining_budget)

    event2 = IncomeEvent.create!(
      budget_period: @budget_period,
      description: "Event After Deficit",
      expected_date: Date.new(2025, 2, 15),
      expected_amount: 2000.00,
      status: "pending",
      account: @account
    )

    # Event2: remaining_budget = 2000, previous_balance = -1000
    # effective_remaining_budget = 2000 + (-1000) = 1000
    assert_equal(2000.0, event2.remaining_budget)
    assert_equal(-1000.0, event2.previous_balance)
    assert_equal(1000.0, event2.effective_remaining_budget)
  end

  test "previous_income_event returns nil when no budget_period" do
    event = IncomeEvent.create!(
      description: "Event Without Period",
      expected_date: Date.new(2025, 1, 15),
      expected_amount: 1000.00,
      status: "pending",
      budget_period: nil,
      account: @account
    )

    assert_nil event.previous_income_event
    assert_equal 0.0, event.previous_balance
  end

  test "rejects a budget period from another account" do
    foreign_period = BudgetPeriod.create!(
      account: accounts(:two),
      name: "Foreign period",
      start_date: Date.current.beginning_of_month,
      end_date: Date.current.end_of_month
    )
    event = IncomeEvent.new(
      account: @account,
      budget_period: foreign_period,
      description: "Cross-account plan",
      expected_date: Date.current,
      expected_amount: 100,
      status: "pending"
    )

    assert_not event.valid?
    assert_includes event.errors[:budget_period], "must belong to the current account"
  end
end
