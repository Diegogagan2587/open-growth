class Financial::DashboardController < ApplicationController
  def show
    @category_count = Category.for_account(Current.account).count
    @financial_account_count = Financial::Account.for_account(Current.account).assets.count
    @financial_liability_count = Financial::Account.for_account(Current.account).liabilities.count
    @financial_entry_count = Financial::Transaction.for_account(Current.account).count
    @plan_count = Financial::Plan.for_account(Current.account).count
    @loan_count = Financial::Loan.for_account(Current.account).count

    render "finance/index"
  end
end
