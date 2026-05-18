class BudgetPeriodsController < ApplicationController
  before_action :set_budget_period, only: [ :show, :edit, :update, :destroy ]

  def index
    @budget_periods = BudgetPeriod.for_account(Current.account).order(start_date: :desc)
  end

  def show
    @planned_expense_status_options = %w[
      pending_to_pay
      saved
      transfer_to_savings
      transferring
      paid
      transferred
      spent
    ]
    @selected_planned_expense_status = params[:planned_expense_status].presence
    @selected_planned_expense_status = nil unless @planned_expense_status_options.include?(@selected_planned_expense_status)

    @income_events = @budget_period.income_events_ordered
    planned_expenses_scope = @budget_period
      .planned_expenses
      .includes(:category, :income_event, :expense_template)
      .references(:income_event)
    planned_expenses_scope = planned_expenses_scope.where(status: @selected_planned_expense_status) if @selected_planned_expense_status.present?

    @planned_expenses = planned_expenses_scope.order(
        Arel.sql("income_events.expected_date ASC"),
        Arel.sql("COALESCE(planned_expenses.position, 2147483647) ASC"),
        Arel.sql("planned_expenses.created_at ASC")
      )
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
