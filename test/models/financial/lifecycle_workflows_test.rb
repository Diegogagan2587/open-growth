require "test_helper"

class Financial::LifecycleWorkflowsTest < ActiveSupport::TestCase
  setup do
    @account = Account.create!(name: "Workflow household")
    @category = Category.create!(account: @account, name: "Household")
    @checking = Financial::Account.create!(account: @account, name: "Checking", account_group: "asset", account_type: "checking", status: "active", opening_balance: 0)
    @card = Financial::Account.create!(account: @account, name: "Card", account_group: "liability", account_type: "credit_card", status: "active", opening_balance: 0)
    @plan = Financial::Plan.create!(account: @account, name: "August", planned_for: Date.new(2026, 8, 1), lifecycle_status: "active")
    Current.account = @account
  end

  teardown { Current.reset }

  test "one funding source receives one transaction and variance closes it" do
    source = @plan.funding_sources.create!(account: @account, description: "Salary", expected_amount: 1_000, expected_date: @plan.planned_for, expected_destination_account: @checking, kind: "income")

    first = Financial::FundingSources::Receipt.create(funding_source: source, amount: 950, transaction_date: @plan.planned_for + 1)
    second = Financial::FundingSources::Receipt.create(funding_source: source, amount: 1_000)

    assert first.success?
    assert second.success?
    assert_equal first.transaction, second.transaction
    assert_equal "closed_with_variance", source.reload.resolution
    assert_equal 1, Financial::Transaction.where(funding_source: source).count

    Financial::FundingSources::Receipt.destroy(funding_source: source)
    assert_equal "pending", source.reload.resolution
    assert_nil source.receipt_transaction
  end

  test "receipt timing does not create a funding variance when the amount matches" do
    source = @plan.funding_sources.create!(account: @account, description: "Salary", expected_amount: 1_000, expected_date: @plan.planned_for, expected_destination_account: @checking, kind: "income")

    result = Financial::FundingSources::Receipt.create(funding_source: source, amount: 1_000, transaction_date: @plan.planned_for + 3)

    assert result.success?
    assert_equal "received", source.reload.resolution
  end

  test "receipts infer ordinary income and preserve refunds" do
    income_source = @plan.funding_sources.create!(account: @account, description: "Salary", expected_amount: 1_000, expected_date: @plan.planned_for, expected_destination_account: @checking, kind: "income")
    refund_source = @plan.funding_sources.create!(account: @account, description: "Returned purchase", expected_amount: 25, expected_date: @plan.planned_for, expected_destination_account: @checking, kind: "refund")

    income = Financial::FundingSources::Receipt.create(funding_source: income_source)
    refund = Financial::FundingSources::Receipt.create(funding_source: refund_source)

    assert_equal "income", income.transaction.transaction_type
    assert_equal "refund", refund.transaction.transaction_type
  end

  test "execution is idempotent and deleting it restores the expectation" do
    planned = Financial::PlannedTransaction.create!(account: @account, plan: @plan, category: @category, source_account: @checking, description: "Groceries", planned_amount: 100, kind: "outflow", planned_execution_date: Date.current, execution_status: "pending", importance: "normal")

    first = Financial::PlannedTransactions::Execution.create(planned_transaction: planned, attributes: { amount: 92 })
    second = Financial::PlannedTransactions::Execution.create(planned_transaction: planned.reload)

    assert first.success?
    assert_equal first.transaction, second.transaction
    assert_equal "applied", planned.reload.execution_status
    assert_equal 1, Financial::Transaction.where(planned_transaction: planned).count

    Financial::PlannedTransactions::Execution.destroy(planned_transaction: planned)
    assert_equal "pending", planned.reload.execution_status
    assert_nil planned.actual_transaction
  end

  test "execution requires a complete account route" do
    planned = Financial::PlannedTransaction.create!(account: @account, plan: @plan, category: @category, description: "Choose account later", planned_amount: 100, planned_execution_date: Date.current, execution_status: "pending", importance: "normal")

    result = Financial::PlannedTransactions::Execution.create(planned_transaction: planned)

    assert_not result.success?
    assert_match "Source account must be selected", result.error_message
    assert_nil planned.reload.actual_transaction
  end

  test "loan becomes active on one disbursement and can be restored before repayments" do
    loan = Financial::Loan.create!(account: @account, name: "Personal loan", principal_amount: 500, lifecycle_status: "simulated", liability_account: @card, destination_account: @checking, payment_frequency: "monthly", number_of_payments: 2)

    first = Financial::Loan::Disbursement.create(loan: loan, plan: @plan)
    second = Financial::Loan::Disbursement.create(loan: loan.reload, plan: @plan)

    assert first.success?
    assert_equal first.transaction, second.transaction
    assert_equal "active", loan.reload.lifecycle_status
    assert_equal 1, loan.transactions.where(transaction_type: "loan_disbursement").count

    Financial::Loan::Disbursement.destroy(loan: loan)
    assert_equal "simulated", loan.reload.lifecycle_status
    assert_empty loan.transactions
  end

  test "loan disbursement requires the simulated lifecycle and an asset destination" do
    active_loan = Financial::Loan.create!(account: @account, name: "Already active", principal_amount: 500, lifecycle_status: "simulated", liability_account: @card, destination_account: @checking)
    active_loan.update!(lifecycle_status: "active")

    result = Financial::Loan::Disbursement.create(loan: active_loan, plan: @plan)

    assert_not result.success?
    assert_match "must be simulated", result.error_message
    assert_empty active_loan.transactions

    invalid_destination = Financial::Loan.create!(account: @account, name: "Invalid route", principal_amount: 500, lifecycle_status: "simulated", liability_account: @card, destination_account: @card)
    result = Financial::Loan::Disbursement.create(loan: invalid_destination, plan: @plan)

    assert_not result.success?
    assert_match "must be an asset account", result.error_message
    assert_empty invalid_destination.transactions
  end

  test "loan disbursement cannot be removed after repayment history exists" do
    loan = Financial::Loan.create!(account: @account, name: "Protected loan", principal_amount: 500, lifecycle_status: "simulated", liability_account: @card, destination_account: @checking)
    disbursement = Financial::Loan::Disbursement.create(loan: loan, plan: @plan)
    assert disbursement.success?
    Financial::Transaction.create!(
      account: @account,
      financial_loan: loan,
      source_account: @checking,
      destination_account: @card,
      transaction_type: "debt_payment",
      transaction_date: Date.current,
      amount: 50,
      description: "First repayment"
    )

    result = Financial::Loan::Disbursement.destroy(loan: loan.reload)

    assert_not result.success?
    assert_match "cannot be removed", result.error_message
    assert_equal "active", loan.reload.lifecycle_status
    assert Financial::Transaction.exists?(disbursement.transaction.id)
  end
end
