class Financial::BudgetPeriodsController < ApplicationController
  before_action :set_budget_period, only: [ :show, :edit, :update, :destroy ]

  def index
    @budget_periods = BudgetPeriod.for_account(Current.account).order(start_date: :desc)
  end

  def show
    @planned_expense_status_options = Financial::PlannedTransaction::EXECUTION_STATUSES
    @selected_planned_expense_status = params[:planned_expense_status].presence
    @selected_planned_expense_status = nil unless @planned_expense_status_options.include?(@selected_planned_expense_status)

    @income_events = @budget_period.financial_plans.chronological
    planned_expenses_scope = @budget_period
      .financial_planned_transactions
      .includes(:category, :plan, :savings_goal)
      .references(:plan)
    planned_expenses_scope = planned_expenses_scope.where(execution_status: @selected_planned_expense_status) if @selected_planned_expense_status.present?

    @planned_expenses = planned_expenses_scope.order(
        Arel.sql("financial_plans.planned_for ASC"),
        Arel.sql("COALESCE(financial_planned_transactions.position, 2147483647) ASC"),
        Arel.sql("financial_planned_transactions.created_at ASC")
      )
    @budget_allocations = @budget_period.financial_budget_allocations.includes(:category).order("categories.name")
    @allocation_categories = Category.for_account(Current.account).where.not(id: @budget_allocations.map(&:category_id)).order(:name)
  end

  def new
    @budget_period = BudgetPeriod.new
  end

  def create
    @budget_period = BudgetPeriod.for_account(Current.account).new(budget_period_params)
    @budget_period.account = Current.account

    respond_to do |format|
      if @budget_period.save
        format.html { redirect_to @budget_period, notice: t("budget_periods.flash.created") }
        format.json { render :show, status: :created, location: @budget_period }
      else
        format.html { render :new, status: :unprocessable_entity }
        format.json { render json: @budget_period.errors, status: :unprocessable_entity }
      end
    end
  end

  def edit
  end

  def update
    respond_to do |format|
      if @budget_period.update(budget_period_params)
        format.html { redirect_to @budget_period, notice: "Budget period was successfully updated." }
        format.json { render :show, status: :ok, location: @budget_period }
      else
        format.html { render :edit, status: :unprocessable_entity }
        format.json { render json: @budget_period.errors, status: :unprocessable_entity }
      end
    end
  end

  def destroy
    @budget_period.destroy!

    respond_to do |format|
      format.html { redirect_to budget_periods_path, status: :see_other, notice: t("budget_periods.flash.destroyed") }
      format.json { head :no_content }
    end
  end

  private

  def set_budget_period
    @budget_period = BudgetPeriod.for_account(Current.account).find(params[:id])
  end

  def budget_period_params
    params.expect(budget_period: [ :name, :period_type, :start_date, :end_date, :total_amount ])
  end
end
