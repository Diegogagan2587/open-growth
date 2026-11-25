require "test_helper"

class Financial::PlannedTransactionTest < ActiveSupport::TestCase
  test "owns its template interface" do
    template = Financial::PlannedTransaction::Template.new(total_amount: 125)

    assert_equal "expense_templates", Financial::PlannedTransaction::Template.table_name
    assert_equal 125.to_d, template.default_amount
    assert_kind_of ExpenseTemplate, template
  end

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

  test "expenses and explicitly reserved neutral movements reduce the plan balance" do
    account = Account.create!(name: "Balance tenant")
    category = Category.create!(account:, name: "Bills")
    checking = Financial::Asset.create!(account:, name: "Checking", account_type: "checking", status: "active", opening_balance: 500)
    savings = Financial::Asset.create!(account:, name: "Savings", account_type: "savings", status: "active", opening_balance: 0)
    card = Financial::Liability.create!(account:, name: "Card", liability_type: "credit_card", status: "active", opening_balance: 100)
    plan = Financial::Plan.create!(account:, name: "Balance", planned_for: Date.current, expected_amount: 1)
    expense = create_transaction(account:, plan:, category:, checking:, description: "Groceries")
    payment = create_transaction(account:, plan:, checking:, card:, description: "Close credit card")
    transfer = create_transaction(account:, plan:, checking:, savings:, description: "Move money")
    payment.update!(commits_plan_funds: true)
    transfer.update!(commits_plan_funds: true)

    assert expense.reduces_plan_balance?
    assert_not payment.budget_consuming?
    assert payment.reduces_plan_balance?
    assert_not transfer.budget_consuming?
    assert transfer.reduces_plan_balance?
    assert_equal 50.to_d, Financial::PlannedTransaction.committed_to_plan.sum(:amount)
  ensure
    Current.account = nil
  end

  test "skipping a pending transaction removes its plan balance impact" do
    account = Account.create!(name: "Skip tenant")
    category = Category.create!(account:, name: "Bills")
    checking = Financial::Asset.create!(account:, name: "Checking", account_type: "checking", status: "active", opening_balance: 500)
    plan = Financial::Plan.create!(account:, name: "Skip", planned_for: Date.current, expected_amount: 1)
    transaction = create_transaction(account:, plan:, category:, checking:, description: "Old bill")

    assert transaction.pending?
    assert transaction.reduces_plan_balance?
    assert transaction.skip
    assert_equal "skipped", transaction.execution_status
    assert_not transaction.pending?
    assert_not transaction.reduces_plan_balance?
    assert_not transaction.skip
  ensure
    Current.account = nil
  end

  test "derives payment timing from preserved due and actual dates" do
    account = Account.create!(name: "Timing Tenant")
    category = Category.create!(account:, name: "Bills")
    asset = Financial::Asset.create!(account:, name: "Checking", account_type: "checking", status: "active", opening_balance: 500)
    plan = Financial::Plan.create!(account:, name: "Timing", planned_for: Date.current, expected_amount: 1)
    transaction = create_transaction(account:, plan:, category:, checking: asset, description: "Timed payment")
    transaction.update!(due_date: Date.new(2026, 9, 17))

    early = Financial::PlannedTransactions::ApplyService.call(planned_transaction: transaction, entry_date: Date.new(2026, 9, 15))

    assert early.success?
    assert_equal Date.new(2026, 9, 17), transaction.reload.due_date
    assert_equal Date.new(2026, 9, 15), transaction.actual_payment_date
    assert_equal :early, transaction.payment_timing

    transaction.update_column(:due_date, nil)
    assert_nil transaction.payment_timing
  ensure
    Current.account = nil
  end

  test "describes complete and incomplete account routes explicitly" do
    account = Account.create!(name: "Route Tenant")
    category = Category.create!(account:, name: "Bills")
    checking = Financial::Asset.create!(account:, name: "Checking", account_type: "checking", status: "active", opening_balance: 500)
    savings = Financial::Asset.create!(account:, name: "Savings", account_type: "savings", status: "active", opening_balance: 0)
    card = Financial::Liability.create!(account:, name: "Card", liability_type: "credit_card", status: "active", opening_balance: 100)
    plan = Financial::Plan.create!(account:, name: "Routes", planned_for: Date.current, expected_amount: 1)

    transfer = create_transaction(account:, plan:, checking:, savings:, description: "Transfer")
    payment = create_transaction(account:, plan:, checking:, card:, description: "Payment")
    expense = create_transaction(account:, plan:, category:, checking:, description: "Expense")
    incomplete = Financial::PlannedTransaction.new(kind: "transfer")

    assert_equal "Checking → Savings", transfer.route_description
    assert_equal "Checking → Card", payment.route_description
    assert_equal "Checking → Expense", expense.route_description
    assert transfer.route_complete?
    assert_not incomplete.route_complete?
    assert_equal "Missing source → Missing destination", incomplete.route_description
  ensure
    Current.account = nil
  end

  test "route selections replace conflicting destinations and rederive movement kind" do
    account = Account.create!(name: "Route correction tenant")
    source = Financial::Asset.create!(account:, name: "Checking", account_type: "checking", status: "active", opening_balance: 100)
    savings = Financial::Asset.create!(account:, name: "Savings", account_type: "savings", status: "active", opening_balance: 0)
    card = Financial::Liability.create!(account:, name: "Card", liability_type: "credit_card", status: "active", opening_balance: 100)
    plan = Financial::Plan.create!(account:, name: "Corrections", planned_for: Date.current, expected_amount: 1)
    transaction = create_transaction(account:, plan:, checking: source, savings:, description: "Correct destination")

    transaction.update!(destination_selection: "liability:#{card.id}")

    assert_equal "liability_payment", transaction.kind
    assert_equal card, transaction.financial_liability
    assert_nil transaction.counterparty_financial_account
  end

  private

  def create_transaction(account:, plan:, description:, category: nil, checking: nil, savings: nil, card: nil)
    Financial::PlannedTransaction.create!(
      account: account,
      plan: plan,
      category: category,
      description: description,
      amount: 25,
      status: "pending_to_pay",
      financial_account: checking,
      counterparty_financial_account: savings,
      financial_liability: card
    )
  end
end
