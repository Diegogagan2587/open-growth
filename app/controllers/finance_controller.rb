class FinanceController < ApplicationController
  def index
    @category_count = Category.for_account(Current.account).count
    @financial_account_count = Financial::Asset.for_account(Current.account).count
    @financial_liability_count = Financial::Liability.for_account(Current.account).count
    @financial_entry_count = Financial::Entry.for_account(Current.account).count
    @plan_count = Financial::Plan.for_account(Current.account).count
    @loan_count = Financial::Loan.where(account: Current.account).count
  end
end
