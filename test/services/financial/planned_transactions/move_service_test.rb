require "test_helper"

class Financial::PlannedTransactions::MoveServiceTest < ActiveSupport::TestCase
  test "selecting the current plan leaves the assignment and position unchanged" do
    account = Account.create!(name: "Same Plan Move Tenant")
    Current.account = account
    category = Category.create!(account: account, name: "Same Plan Food")
    plan = Financial::Plan.create!(account: account, name: "Current plan", planned_for: Date.current, expected_amount: 1)
    transaction = Financial::PlannedTransaction.create!(account: account, plan: plan, category: category, description: "First task", amount: 10, status: "pending_to_pay")
    Financial::PlannedTransaction.create!(account: account, plan: plan, category: category, description: "Second task", amount: 20, status: "pending_to_pay")

    result = Financial::PlannedTransactions::MoveService.call(planned_transaction: transaction, target_plan: plan)

    assert result.success?
    assert_equal plan, transaction.reload.plan
    assert_equal 1, transaction.position
  ensure
    Current.account = nil
  end

  test "moves pending transactions but rejects applied transactions" do
    account = Account.create!(name: "Move Tenant")
    Current.account = account
    category = Category.create!(account: account, name: "Food")
    source = Financial::Plan.create!(account: account, name: "Source", planned_for: Date.current, expected_amount: 1)
    target = Financial::Plan.create!(account: account, name: "Target", planned_for: Date.current + 1, expected_amount: 1)
    transaction = Financial::PlannedTransaction.create!(account: account, plan: source, category: category, description: "Task", amount: 10, status: "pending_to_pay")

    moved = Financial::PlannedTransactions::MoveService.call(planned_transaction: transaction, target_plan: target)
    assert moved.success?
    assert_equal target, transaction.reload.plan
    assert_equal 1, transaction.position

    transaction.update!(execution_status: "applied")
    rejected = Financial::PlannedTransactions::MoveService.call(planned_transaction: transaction, target_plan: source)
    assert_not rejected.success?
    assert_equal target, transaction.reload.plan
  ensure
    Current.account = nil
  end
end
