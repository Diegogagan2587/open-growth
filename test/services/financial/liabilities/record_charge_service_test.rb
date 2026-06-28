require "test_helper"

class Financial::Liabilities::RecordChargeServiceTest < ActiveSupport::TestCase
  def setup
    @account = Account.create!(name: "Tenant")
    Current.account = @account

    @liability = Financial::Liability.create!(
      account: @account,
      name: "Main Card",
      liability_type: "credit_card",
      status: "active",
      opening_balance: 0
    )

    @category = Category.create!(
      account: @account,
      name: "Food"
    )

    @budget_period = BudgetPeriod.create!(
      account: @account,
      name: "April",
      start_date: Date.current.beginning_of_month,
      end_date: Date.current.end_of_month,
      total_amount: 1000
    )
  end

  def teardown
    Current.account = nil
  end

  test "creates liability_charge entry without creating expense" do
    result = Financial::Liabilities::RecordChargeService.call(
      liability: @liability, # Liability Account
      amount: 50,
      description: "Coca Cola",
      entry_date: Date.current,
      category_id: @category.id,
      budget_period_id: @budget_period.id
    )

    assert result.success?
    assert_equal 0, Expense.for_account(@account).count
    assert_equal 1, Financial::Entry.for_account(@account).where(entry_type: "liability_charge").count
    assert_equal @category.id, result.entry.category_id
    assert_equal @budget_period.id, result.entry.budget_period_id
    assert_equal 50.to_d, @liability.reload.current_balance
  end

  test "fails when amount exceeds constraints" do
    result = Financial::Liabilities::RecordChargeService.call(
      liability: @liability,
      amount: 0,
      description: "Invalid",
      entry_date: Date.current,
      category_id: @category.id,
      budget_period_id: @budget_period.id
    )

    assert_not result.success?
    assert_equal "Amount must be greater than 0", result.error_message
  end
end
