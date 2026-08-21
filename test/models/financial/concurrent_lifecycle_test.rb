require "test_helper"

class Financial::ConcurrentLifecycleTest < ActiveSupport::TestCase
  self.use_transactional_tests = false

  setup do
    @account = Account.create!(name: "Concurrent finance #{SecureRandom.hex(4)}")
    @category = Category.create!(account: @account, name: "Concurrent category")
    @checking = Financial::Account.create!(account: @account, name: "Concurrent checking", account_group: "asset", account_type: "checking", status: "active", opening_balance: 0)
    @liability = Financial::Account.create!(account: @account, name: "Concurrent loan", account_group: "liability", account_type: "personal_credit", status: "active", opening_balance: 0)
    @plan = Financial::Plan.create!(account: @account, name: "Concurrent plan", planned_for: Date.current)
  end

  teardown do
    Financial::Transaction.where(account: @account).delete_all
    Financial::LoanInstallment.where(account: @account).delete_all
    Financial::FundingSource.where(account: @account).delete_all
    Financial::PlannedTransaction.where(account: @account).delete_all
    Financial::Loan.where(account: @account).delete_all
    Financial::Plan.where(account: @account).delete_all
    Financial::Account.where(account: @account).delete_all
    Category.where(account: @account).delete_all
    @account.delete
  end

  test "receipt execution and disbursement stay singular under concurrent requests" do
    source = @plan.funding_sources.create!(account: @account, description: "Salary", expected_amount: 100, expected_date: Date.current, expected_destination_account: @checking)
    run_concurrently(2) { Financial::FundingSources::Receipt.create(funding_source: Financial::FundingSource.find(source.id)) }
    assert_equal 1, Financial::Transaction.where(funding_source_id: source.id).count

    planned = Financial::PlannedTransaction.create!(account: @account, plan: @plan, category: @category, source_account: @checking, description: "Expense", planned_amount: 20, kind: "outflow", execution_status: "pending", importance: "normal")
    run_concurrently(2) { Financial::PlannedTransactions::Execution.create(planned_transaction: Financial::PlannedTransaction.find(planned.id)) }
    assert_equal 1, Financial::Transaction.where(planned_transaction_id: planned.id).count

    loan = Financial::Loan.create!(account: @account, name: "Loan", principal_amount: 200, lifecycle_status: "simulated", liability_account: @liability, destination_account: @checking)
    run_concurrently(2) { Financial::Loan::Disbursement.create(loan: Financial::Loan.find(loan.id), plan: Financial::Plan.find(@plan.id)) }
    assert_equal 1, Financial::Transaction.where(financial_loan_id: loan.id, transaction_type: "loan_disbursement").count
  end

  private

  def run_concurrently(count, &block)
    errors = Queue.new
    threads = count.times.map do
      Thread.new do
        ActiveRecord::Base.connection_pool.with_connection { block.call }
      rescue StandardError => error
        errors << error
      end
    end
    threads.each(&:join)
    raise errors.pop unless errors.empty?
  end
end
