require "test_helper"

class Financial::PlannedTransactions::ApplyServiceTest < ActiveSupport::TestCase
  test "applies with actual changes once without rewriting the plan" do
    account = Account.create!(name: "Apply Tenant")
    Current.account = account
    category = Category.create!(account: account, name: "Food")
    asset = Financial::Asset.create!(account: account, name: "Checking", account_type: "checking", status: "active", opening_balance: 0)
    plan = Financial::Plan.create!(account: account, name: "July", planned_for: Date.current, expected_amount: 1)
    transaction = Financial::PlannedTransaction.create!(
      account: account,
      plan: plan,
      category: category,
      financial_account: asset,
      description: "Planned groceries",
      amount: 100,
      planned_for: Date.current,
      status: "pending_to_pay",
      kind: "outflow"
    )

    first = Financial::PlannedTransactions::ApplyService.call(
      planned_transaction: transaction,
      amount: 92,
      entry_date: Date.current + 1,
      description: "Actual groceries"
    )
    second = Financial::PlannedTransactions::ApplyService.call(planned_transaction: transaction.reload)

    assert first.success?
    assert second.success?
    assert_equal first.entry, second.entry
    assert_equal 1, Financial::Entry.where(planned_expense: transaction).count
    assert_equal 92.to_d, first.entry.amount
    assert_equal Date.current + 1, first.entry.entry_date
    assert_equal 100.to_d, transaction.reload.amount
    assert_equal "applied", transaction.execution_status
  ensure
    Current.account = nil
  end
end
