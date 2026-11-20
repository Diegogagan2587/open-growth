class Financial::CategoryBudgetsController < ApplicationController
  before_action :set_budget, only: [ :update, :destroy ]

  def index
    @period = params[:period].to_s.in?(%w[week two_weeks month custom]) ? params[:period] : "month"
    @range_start, @range_end = selected_range
    @rows = Financial::CategoryBudgets::Overview.for(account: Current.account, range_start: @range_start, range_end: @range_end)
    assigned_ids = Financial::CategoryBudget.where(account: Current.account).select(:category_id)
    @categories = Category.for_account(Current.account).where.not(id: assigned_ids).order(:name)
    @new_budget = Financial::CategoryBudget.new(frequency: "monthly", starts_on: Date.current)
  end

  def create
    @budget = Financial::CategoryBudget.new(budget_params.merge(account: Current.account))
    if @budget.save
      redirect_to finance_category_budgets_path, notice: t("category_budgets.flash.created")
    else
      redirect_to finance_category_budgets_path, alert: t("category_budgets.flash.save_failed")
    end
  end

  def update
    if @budget.update(budget_params)
      redirect_to finance_category_budgets_path, notice: t("category_budgets.flash.updated")
    else
      redirect_to finance_category_budgets_path, alert: t("category_budgets.flash.save_failed")
    end
  end

  def destroy
    @budget.destroy!
    redirect_to finance_category_budgets_path, status: :see_other, notice: t("category_budgets.flash.removed")
  end

  private

  def set_budget
    @budget = Financial::CategoryBudget.where(account: Current.account).find(params[:id])
  end

  def budget_params
    params.expect(financial_category_budget: [ :category_id, :amount, :frequency, :custom_days, :starts_on ])
  end

  def selected_range
    if params[:period] == "custom" && params[:start_date].present? && params[:end_date].present?
      start_date = Date.iso8601(params[:start_date])
      end_date = Date.iso8601(params[:end_date])
      return [ start_date, end_date ] if end_date >= start_date && (end_date - start_date).to_i <= 366
    end

    finish = Date.current
    case params[:period]
    when "week" then [ finish.beginning_of_week, finish ]
    when "two_weeks" then [ finish - 13.days, finish ]
    else [ finish.beginning_of_month, finish ]
    end
  rescue Date::Error
    finish = Date.current
    [ finish.beginning_of_month, finish ]
  end
end
