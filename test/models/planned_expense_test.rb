require "test_helper"

class PlannedExpenseTest < ActiveSupport::TestCase
  def setup
    @account = Account.create!(name: "Test Account")
    Current.account = @account

    @budget_period = BudgetPeriod.create!(
      name: "Test Period",
      start_date: Date.new(2025, 1, 1),
      end_date: Date.new(2025, 12, 31),
      account: @account
    )

    @income_event = IncomeEvent.create!(
      budget_period: @budget_period,
      description: "Test Income Event",
      expected_date: Date.new(2025, 1, 15),
      expected_amount: 1000.00,
      status: "pending",
      account: @account
    )

    @category = Category.create!(name: "Test Category", account: @account)

    @source_account = Financial::Asset.create!(
      name: "Test Checking",
      account: @account,
      account_type: "checking",
      status: "active",
      opening_balance: 1000.00
    )

    @destination_account = Financial::Asset.create!(
      name: "Test Savings",
      account: @account,
      account_type: "savings",
      status: "active",
      opening_balance: 200.00
    )

    @liability = Financial::Liability.create!(
      name: "Test Credit Card",
      account: @account,
      liability_type: "credit_card",
      status: "active",
      opening_balance: 500.00
    )
  end

  def teardown
    Current.account = nil
  end

  test "final status regular flow creates outflow entry" do
    planned_expense = PlannedExpense.create!(
      income_event: @income_event,
      category: @category,
      description: "Regular expense",
      amount: 100.00,
      status: "spent",
      source_selection: "asset:#{@source_account.id}"
    )

    result = PlannedExpenses::ExecuteService.call(planned_expense: planned_expense, target_status: "spent")

    assert result.success?
    planned_expense.reload
    assert planned_expense.financial_entry.present?
    assert_equal "outflow", planned_expense.financial_entry.entry_type
    assert_equal @source_account.id, planned_expense.financial_entry.financial_account_id
  end

  test "budget-consuming expense requires a category" do
    planned_expense = PlannedExpense.new(
      income_event: @income_event,
      description: "Uncategorized expense",
      amount: 25,
      status: "pending_to_pay",
      financial_account: @source_account
    )

    assert_not planned_expense.valid?
    assert_includes planned_expense.errors[:category], "can't be blank"
  end

  test "uncategorized movements are valid and have useful labels" do
    transfer = PlannedExpense.create!(
      income_event: @income_event,
      description: "Move money",
      amount: 25,
      status: "pending_to_pay",
      financial_account: @source_account,
      counterparty_financial_account: @destination_account
    )
    payment = PlannedExpense.create!(
      income_event: @income_event,
      description: "Pay card",
      amount: 25,
      status: "pending_to_pay",
      financial_account: @source_account,
      financial_liability: @liability
    )

    assert_nil transfer.category
    assert_equal "Transfer", transfer.classification_label
    assert_nil payment.category
    assert_equal "Card payment", payment.classification_label
  end

  test "apply! creates transfer entry when destination account is present" do
    planned_expense = PlannedExpense.create!(
      income_event: @income_event,
      category: @category,
      description: "Move money to savings",
      amount: 100.00,
      status: "pending_to_pay",
      source_selection: "asset:#{@source_account.id}",
      financial_account: @source_account,
      counterparty_financial_account: @destination_account
    )

    planned_expense.apply!
    planned_expense.reload

    assert_equal "transferred", planned_expense.status
    assert_equal 0, Expense.count
    assert_equal 1, Financial::Entry.count

    entry = planned_expense.financial_entry
    assert_equal "transfer", entry.entry_type
    assert_equal @source_account.id, entry.financial_account_id
    assert_equal @destination_account.id, entry.counterparty_financial_account_id
    assert_equal planned_expense.id, entry.planned_expense_id
  end

  test "apply! creates liability payment entry when liability is present" do
    planned_expense = PlannedExpense.create!(
      income_event: @income_event,
      category: @category,
      description: "Pay credit card",
      amount: 75.00,
      status: "pending_to_pay",
      source_selection: "asset:#{@source_account.id}",
      financial_account: @source_account,
      financial_liability: @liability
    )

    planned_expense.apply!
    planned_expense.reload

    assert_equal "paid", planned_expense.status
    assert_equal 0, Expense.count
    assert_equal 1, Financial::Entry.count

    entry = planned_expense.financial_entry
    assert_equal "liability_payment", entry.entry_type
    assert_equal @source_account.id, entry.financial_account_id
    assert_equal @liability.id, entry.financial_liability_id
    assert_equal planned_expense.id, entry.planned_expense_id
  end

  test "transfers and liability payments do not consume planned budget" do
    PlannedExpense.create!(
      income_event: @income_event,
      category: @category,
      description: "Groceries",
      amount: 100.00,
      status: "pending_to_pay",
      financial_account: @source_account
    )
    transfer = PlannedExpense.create!(
      income_event: @income_event,
      category: @category,
      description: "Move to savings",
      amount: 200.00,
      status: "pending_to_pay",
      financial_account: @source_account,
      counterparty_financial_account: @destination_account
    )
    liability_payment = PlannedExpense.create!(
      income_event: @income_event,
      category: @category,
      description: "Pay credit card",
      amount: 300.00,
      status: "pending_to_pay",
      financial_account: @source_account,
      financial_liability: @liability
    )

    assert_not transfer.budget_consuming?
    assert_not liability_payment.budget_consuming?
    assert_equal 100.to_d, @income_event.total_planned
    assert_equal 900.to_d, @income_event.remaining_budget
    assert_equal 100.to_d, @budget_period.total_planned
  end

  test "execute service is idempotent for transaction creation" do
    planned_expense = PlannedExpense.create!(
      income_event: @income_event,
      category: @category,
      description: "Idempotent outflow",
      amount: 45.00,
      status: "pending_to_pay",
      source_selection: "asset:#{@source_account.id}"
    )

    first = PlannedExpenses::ExecuteService.call(planned_expense: planned_expense, target_status: "paid")
    second = PlannedExpenses::ExecuteService.call(planned_expense: planned_expense, target_status: "paid")

    assert first.success?
    assert second.success?
    assert_equal 1, Financial::Entry.where(planned_expense_id: planned_expense.id).count
  end

  test "execute service fails when regular outflow lacks source account" do
    planned_expense = PlannedExpense.create!(
      income_event: @income_event,
      category: @category,
      description: "No source",
      amount: 30.00,
      status: "pending_to_pay"
    )

    result = PlannedExpenses::ExecuteService.call(planned_expense: planned_expense, target_status: "paid")

    assert_not result.success?
    assert result.error_message.present?
  end
end
