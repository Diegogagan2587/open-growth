class Financial::PlansController < ApplicationController
  before_action :set_plan, only: %i[show edit update destroy]
  before_action :load_form_collections, only: [ :new, :create, :edit, :update ]
  before_action :load_plan_collections, only: :show

  def index
    @budget_period = BudgetPeriod.for_account(Current.account).find_by(id: params[:budget_period_id])
    @month = params[:month].to_s if params[:month].to_s.match?(/\A\d{4}-(0[1-9]|1[0-2])\z/)
    @status = params[:status].to_s if params[:status].to_s.in?(Financial::Plan::LIFECYCLE_STATUSES)
    @plans = Financial::Plan.for_account(Current.account)
    @plans = @plans.where(budget_period: @budget_period) if @budget_period
    @plans = @plans.where(planned_for: Date.strptime(@month, "%Y-%m").all_month) if @month
    @plans = @plans.where(lifecycle_status: @status) if @status
    @plans = @plans
      .includes(:funding_sources)
      .chronological
      .reverse_order
  end

  def show
    @projection = Financial::PlanProjection.for(@plan)
    @actuals = Financial::PlanActuals.for(@plan)
    @funding_sources = @plan.funding_sources.includes(:receipt_entry).order(:expected_date, :id)
    @planned_transactions = @plan.planned_transactions.by_position.to_a
    applied_transactions = @planned_transactions.reject { |transaction| transaction.execution_status == "pending" }
    ActiveRecord::Associations::Preloader.new(records: applied_transactions, associations: :financial_entry).call if applied_transactions.any?
    @actual_entries = @plan.financial_entries.includes(:category).by_date
  end

  def new
    budget_period = BudgetPeriod.for_account(Current.account).find_by(id: params[:budget_period_id])
    @plan = Financial::Plan.new(planned_for: Date.current, lifecycle_status: "draft", budget_period: budget_period, account: Current.account)
    @funding_source = Financial::FundingSource.new(expected_date: Date.current, kind: "income")
  end

  def create
    @plan = Financial::Plan.new(plan_params.merge(account: Current.account, expected_amount: initial_funding_params[:expected_amount], status: "pending", income_type: "regular"))
    @funding_source = @plan.funding_sources.new(initial_funding_params.merge(account: Current.account))

    if save_plan_with_initial_funding
      redirect_to finance_plan_path(@plan), notice: "Plan created"
    else
      render :new, status: :unprocessable_entity
    end
  end

  def edit
  end

  def update
    if @plan.update(plan_params)
      redirect_to finance_plan_path(@plan), notice: "Plan updated"
    else
      render :edit, status: :unprocessable_entity
    end
  end

  def destroy
    if @plan.destroy
      redirect_to finance_plans_path, status: :see_other, notice: "Draft plan deleted"
    else
      redirect_to finance_plan_path(@plan), alert: @plan.errors.full_messages.to_sentence
    end
  end

  private

  def set_plan
    @plan = Financial::Plan.for_account(Current.account).find(params[:id])
  end

  def plan_params
    permitted = params.expect(financial_plan: [ :name, :planned_for, :budget_period_id, :lifecycle_status ])
    if action_name == "update" && permitted[:lifecycle_status].present? && !permitted[:lifecycle_status].in?(%w[draft active])
      permitted.delete(:lifecycle_status)
    end
    permitted
  end

  def initial_funding_params
    params.expect(financial_funding_source: [
      :description,
      :expected_amount,
      :expected_date,
      :kind,
      :expected_destination_asset_id,
      :expected_destination_liability_id
    ])
  end

  def save_plan_with_initial_funding
    ActiveRecord::Base.transaction do
      @plan.save!
      @funding_source.financial_plan = @plan
      @funding_source.save!
    end
    true
  rescue ActiveRecord::RecordInvalid
    false
  end

  def load_form_collections
    @budget_periods = BudgetPeriod.for_account(Current.account).order(start_date: :desc)
    @assets = Financial::Asset.for_account(Current.account).active.order(:name)
    @liabilities = Financial::Liability.for_account(Current.account).active.order(:name)
  end

  def load_plan_collections
    @assets = Financial::Asset.for_account(Current.account).active.order(:name)
    @liabilities = Financial::Liability.for_account(Current.account).active.order(:name)
    @categories = Category.for_account(Current.account).order(:name)
    @other_plans = Financial::Plan.for_account(Current.account).where.not(id: @plan.id).chronological
  end
end
