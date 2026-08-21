require "test_helper"

class Financial::TransactionTest < ActiveSupport::TestCase
  setup do
    @account = Account.create!(name: "Transaction household")
    @category = Category.create!(account: @account, name: "Food")
    @checking = Financial::Account.create!(account: @account, name: "Checking", account_group: "asset", account_type: "checking", status: "active", opening_balance: 100)
    @card = Financial::Account.create!(account: @account, name: "Card", account_group: "liability", account_type: "credit_card", status: "active", opening_balance: 0)
    Current.account = @account
  end

  teardown { Current.reset }

  test "editable transactions clear reconciliation only for bank-visible corrections" do
    transaction = Financial::Transaction.create!(account: @account, category: @category, source_account: @checking, transaction_type: "expense", transaction_date: Date.current, amount: 12, description: "Coffee")
    transaction.reconcile!

    transaction.correct!(description: "Coffee and bread", notes: "Receipt in wallet")
    assert transaction.reconciled_at?

    transaction.correct!(amount: 13)
    assert_nil transaction.reconciled_at
  end

  test "routing applies opposite balance effects to assets and liabilities" do
    charge = Financial::Transaction.create!(account: @account, category: @category, source_account: @card, transaction_type: "expense", transaction_date: Date.current, amount: 40, description: "Groceries")
    payment = Financial::Transaction.create!(account: @account, source_account: @checking, destination_account: @card, transaction_type: "debt_payment", transaction_date: Date.current, amount: 15, description: "Card payment")

    assert_equal 25.to_d, @card.current_balance
    assert_equal 85.to_d, @checking.current_balance
    assert_equal 40.to_d, charge.net_liability_effect
    assert_equal(-15.to_d, payment.net_asset_effect)
  end

  test "rejects associations owned by another household" do
    other = Account.create!(name: "Other household")
    foreign_account = Financial::Account.create!(account: other, name: "Foreign checking", account_group: "asset", account_type: "checking", status: "active", opening_balance: 0)
    transaction = Financial::Transaction.new(account: @account, category: @category, source_account: foreign_account, transaction_type: "expense", transaction_date: Date.current, amount: 1, description: "Invalid")

    assert_not transaction.valid?
    assert_includes transaction.errors[:source_account], "must belong to the current account"
  end

  test "infers the transaction type from its account route" do
    savings = Financial::Account.create!(account: @account, name: "Savings", account_group: "asset", account_type: "savings", status: "active", opening_balance: 0)
    transfer = Financial::Transaction.new(
      account: @account,
      source_account: @checking,
      destination_account: savings,
      transaction_date: Date.current,
      amount: 1,
      description: "Move money"
    )

    assert transfer.valid?
    assert_equal "transfer", transfer.transaction_type
  end

  test "reclassifies an outgoing transaction when its account route changes" do
    savings = Financial::Account.create!(account: @account, name: "Route savings", account_group: "asset", account_type: "savings", status: "active", opening_balance: 0)
    transaction = Financial::Transaction.create!(account: @account, category: @category, source_account: @checking, transaction_date: Date.current, amount: 1, description: "Expense")

    transaction.update!(destination_account: savings, category: nil)

    assert_equal "transfer", transaction.transaction_type
  end

  test "reclassifies a liability-funded route as a loan disbursement" do
    disbursement = Financial::Transaction.new(
      account: @account,
      source_account: @card,
      destination_account: @checking,
      transaction_type: "transfer",
      transaction_date: Date.current,
      amount: 1,
      description: "Invalid"
    )

    assert_predicate disbursement, :valid?
    assert_equal "loan_disbursement", disbursement.transaction_type
  end

  test "infers inflows and preserves their explicit semantic type" do
    income = Financial::Transaction.new(account: @account, destination_account: @checking, transaction_date: Date.current, amount: 1, description: "Salary")
    refund = Financial::Transaction.new(account: @account, destination_account: @checking, transaction_type: "refund", transaction_date: Date.current, amount: 1, description: "Refund")

    assert_predicate income, :valid?
    assert_equal "income", income.transaction_type
    assert_predicate refund, :valid?
    assert_equal "refund", refund.transaction_type
  end

  test "derives its public type vocabulary from account routing" do
    assert_equal Financial::Transactions::AccountRoute.transaction_types, Financial::Transaction.transaction_types
  end

  test "keeps inflow as the established alias for income" do
    refund = Financial::Transaction.new(transaction_type: "refund")
    adjustment = Financial::Transaction.new(transaction_type: "adjustment")

    assert_predicate refund, :income?
    assert_predicate refund, :inflow?
    assert_predicate refund, :funding?
    assert_not adjustment.income?
    assert_not adjustment.inflow?
    assert_not adjustment.funding?
  end
end
