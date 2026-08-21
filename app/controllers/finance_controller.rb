class FinanceController < ApplicationController
  def index
    @category_count = Category.for_account(Current.account).count
    @financial_account_count = Financial::Asset.for_account(Current.account).count
    @financial_liability_count = Financial::Liability.for_account(Current.account).count
    @financial_entry_count = Financial::Entry.for_account(Current.account).count
    @pending_expectation_count = Financial::FundingSource.where(account: Current.account)
      .joins(:financial_plan).left_joins(:receipt_transaction)
      .where(resolution: "pending", financial_transactions: { id: nil }, financial_plans: { lifecycle_status: %w[draft active] })
      .where.not(kind: "borrowed").count +
      Financial::PlannedTransaction.for_account(Current.account).left_joins(:actual_transaction, :plan)
        .where(execution_status: "pending", financial_transactions: { id: nil })
        .where("financial_plans.id IS NULL OR financial_plans.lifecycle_status IN (?)", %w[draft active]).count
    @plan_count = Financial::Plan.for_account(Current.account).count
    @loan_count = Financial::Loan.where(account: Current.account).count
  end
end
