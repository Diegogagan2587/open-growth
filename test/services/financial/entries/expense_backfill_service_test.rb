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
end
