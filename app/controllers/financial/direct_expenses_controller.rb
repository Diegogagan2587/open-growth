class Financial::DirectExpensesController < ApplicationController
  before_action :set_income_event
  before_action :load_form_collections, only: [ :new, :create ]

  def new
    @financial_entry = Financial::Entry.new(
      income_event: @income_event,
      budget_period: @income_event.budget_period,
      entry_date: Date.current
    )
  end

  private
  
  def set_income_event
    @income_event = IncomeEvent.for_account(Current.account).find(params[:income_event_id])
  end

  
  def load_form_collections
    @categories = Category.for_account(Current.account).order(:name)
    @budget_periods = BudgetPeriod.for_account(Current.account).order(start_date: :desc)
    @financial_accounts = Financial::Asset.for_account(Current.account).active.order(:name)
    @financial_liabilities = Financial::Liability.for_account(Current.account).active.order(:name)
  end
end
