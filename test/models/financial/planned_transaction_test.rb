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

  test "infers kind from an account route and allows a missing source while planning" do
    account = Account.create!(name: "Routing Tenant")
    card = Financial::Account.create!(account: account, name: "Card", account_group: "liability", account_type: "credit_card", status: "active", opening_balance: 0)
    transaction = Financial::PlannedTransaction.new(
      account: account,
      destination_account: card,
      description: "Future payment",
      amount: 10,
      status: "pending_to_pay"
    )

    assert transaction.valid?
    assert_equal "liability_payment", transaction.kind
  end
  test "reclassifies when its account route changes" do
    account = Account.create!(name: "Changing Route Tenant")
    category = Category.create!(account: account, name: "Food")
    checking = Financial::Account.create!(account: account, name: "Checking", account_group: "asset", account_type: "checking", status: "active", opening_balance: 0)
    savings = Financial::Account.create!(account: account, name: "Savings", account_group: "asset", account_type: "savings", status: "active", opening_balance: 0)
    transaction = Financial::PlannedTransaction.create!(account: account, category: category, source_account: checking, description: "Groceries", amount: 10, status: "pending_to_pay")

    transaction.update!(destination_account: savings, budget_consuming: false, category: nil)

    assert_equal "transfer", transaction.kind
  end
end
