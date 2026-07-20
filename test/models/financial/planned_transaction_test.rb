require "test_helper"

class Financial::PlannedTransactionTest < ActiveSupport::TestCase
  test "may remain unassigned without a position" do
    account = Account.create!(name: "Unassigned Tenant")
    category = Category.create!(account: account, name: "Food")

    transaction = Financial::PlannedTransaction.create!(
      account: account,
      category: category,
      description: "Someday",
      amount: 10,
      status: "pending_to_pay"
    )

    assert_nil transaction.plan
    assert_nil transaction.position
    assert_includes Financial::PlannedTransaction.unassigned, transaction
  end
end
