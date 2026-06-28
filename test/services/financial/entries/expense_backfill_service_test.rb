require "test_helper"

class Financial::Entries::ExpenseBackfillServiceTest < ActiveSupport::TestCase
  setup do
    @account = accounts(:one)
    @category = categories(:one)
    @income_event = income_events(:one)
    @budget_period = BudgetPeriod.create!(
      name: "Backfill Period",
      start_date: Date.current.beginning_of_month,
      end_date: Date.current.end_of_month,
      total_amount: 1000,
      account: @account
    )
    @asset = Financial::Asset.create!(
      account: @account,
      name: "Legacy Checking",
      account_type: "checking",
      status: "active",
      opening_balance: 0
    )
  end

  test "backfills legacy expense routing from planned expense" do
    planned_expense = PlannedExpense.create!(
      account: @account,
      income_event: @income_event,
      category: @category,
      financial_account: @asset,
      description: "Legacy planned expense",
      amount: 20,
      status: "paid"
    )
    expense = Expense.new(
      account: @account,
      category: @category,
      budget_period: @budget_period,
      income_event: @income_event,
      planned_expense: planned_expense,
      date: Date.current,
      amount: 20,
      description: "Legacy expense without source"
    )
    expense.save!(validate: false)

    assert_difference("Financial::Entry.count", 1) do
      result = Financial::Entries::ExpenseBackfillService.call(scope: Expense.where(id: expense.id))
      assert_empty result.errors
      assert_equal 1, result.created
    end

    entry = expense.reload.financial_entry
    assert_equal "outflow", entry.entry_type
    assert_equal @asset, entry.financial_account
  end

  test "links existing planned expense entry instead of creating duplicate" do
    planned_expense = PlannedExpense.create!(
      account: @account,
      income_event: @income_event,
      category: @category,
      financial_account: @asset,
      description: "Already executed",
      amount: 30,
      status: "paid"
    )
    entry = Financial::Entry.create!(
      account: @account,
      income_event: @income_event,
      planned_expense: planned_expense,
      category: @category,
      budget_period: @budget_period,
      financial_account: @asset,
      entry_type: "outflow",
      entry_date: Date.current,
      amount: 30,
      description: "Already executed"
    )
    expense = Expense.new(
      account: @account,
      category: @category,
      budget_period: @budget_period,
      income_event: @income_event,
      planned_expense: planned_expense,
      date: Date.current,
      amount: 30,
      description: "Legacy expense without source"
    )
    expense.save!(validate: false)

    assert_no_difference("Financial::Entry.count") do
      result = Financial::Entries::ExpenseBackfillService.call(scope: Expense.where(id: expense.id))
      assert_empty result.errors
      assert_equal 1, result.updated
    end

    assert_equal expense, entry.reload.expense
  end

  test "creates and reuses fallback account for unrouted legacy expenses" do
    first_expense = Expense.new(
      account: @account,
      category: @category,
      budget_period: @budget_period,
      income_event: @income_event,
      date: Date.current,
      amount: 40,
      description: "First legacy expense without any routing"
    )
    first_expense.save!(validate: false)
    second_expense = Expense.new(
      account: @account,
      category: @category,
      budget_period: @budget_period,
      income_event: @income_event,
      date: Date.current,
      amount: 50,
      description: "Second legacy expense without any routing"
    )
    second_expense.save!(validate: false)

    assert_difference("Financial::Asset.where(name: 'Legacy Expense Migration').count", 1) do
      result = Financial::Entries::ExpenseBackfillService.call(scope: Expense.where(id: [ first_expense.id, second_expense.id ]))
      assert_empty result.errors
    end

    fallback = Financial::Asset.find_by!(account: @account, name: "Legacy Expense Migration")
    assert_equal fallback, first_expense.reload.financial_entry.financial_account
    assert_equal fallback, second_expense.reload.financial_entry.financial_account
  end
end
