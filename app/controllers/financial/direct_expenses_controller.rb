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

  def create
    attrs = direct_expense_params
    result = Financial::Entries::RecordExpenseService.call(
      account: Current.account,
      amount: attrs[:amount],
      entry_date: attrs[:date] || attrs[:entry_date],
      description: attrs[:description],
      category_id: attrs[:category_id],
      budget_period_id: attrs[:budget_period_id].presence || @income_event.budget_period_id,
      source_selection: attrs[:source_selection],
      destination_selection: attrs[:destination_selection],
      income_event_id: @income_event.id
    )

    if result.success?
      redirect_to @income_event, notice: t("expenses.flash.quick_created")
    else
      @financial_entry = Financial::Entry.new(
        income_event: @income_event,
        budget_period_id: attrs[:budget_period_id].presence || @income_event.budget_period_id,
        entry_date: attrs[:date] || attrs[:entry_date],
        amount: attrs[:amount],
        description: attrs[:description],
        category_id: attrs[:category_id]
      )
      @financial_entry.errors.add(:base, result.error_message)
      flash.now[:alert] = result.error_message
      render :new, status: :unprocessable_entity
    end
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
