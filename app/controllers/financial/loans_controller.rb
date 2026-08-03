class Financial::LoansController < ApplicationController
  before_action :set_loan, only: [ :show, :edit, :update, :destroy, :activate, :generate_installments, :plan_installment ]
  before_action :load_collections, only: [ :new, :create, :edit, :update, :show ]

  def index
    @loans = Financial::Loan.for_account(Current.account).includes(:liability).order(created_at: :desc)
  end

  def show
    @installments = @loan.installments.includes(:planned_transaction, :payment_entry).order(:installment_number)
    @entries = @loan.entries.by_date
  end

  def new
    @loan = Financial::Loan.new(lifecycle_status: "simulated", payment_frequency: "monthly")
  end

  def create
    @loan = Financial::Loan.new(loan_params.merge(account: Current.account, lifecycle_status: "simulated"))
    if @loan.save
      redirect_to finance_loan_path(@loan), notice: "Loan simulation created"
    else
      render :new, status: :unprocessable_entity
    end
  end

  def edit
  end

  def update
    if @loan.update(loan_params)
      redirect_to finance_loan_path(@loan), notice: "Loan updated"
    else
      render :edit, status: :unprocessable_entity
    end
  end

  def destroy
    if @loan.lifecycle_status == "simulated" && @loan.entries.empty? && @loan.destroy
      redirect_to finance_loans_path, status: :see_other, notice: "Simulation deleted"
    else
      redirect_to finance_loan_path(@loan), alert: "Only a simulation without actual entries can be deleted"
    end
  end

  def activate
    plan = Financial::Plan.for_account(Current.account).find(params[:plan_id])
    result = Financial::Loans::ActivateService.call(loan: @loan, plan: plan)
    redirect_to finance_loan_path(@loan), notice: ("Loan activated and disbursed" if result.success?), alert: (result.error_message unless result.success?)
  end

  def generate_installments
    result = Financial::Loans::GenerateInstallmentsService.call(loan: @loan, start_date: params[:start_date])
    redirect_to finance_loan_path(@loan), notice: ("Installments generated" if result.success?), alert: (result.error_message unless result.success?)
  end

  def plan_installment
    installment = @loan.installments.find(params[:installment_id])
    plan = Financial::Plan.for_account(Current.account).find(params[:plan_id])
    source_account = Financial::Asset.for_account(Current.account).active.find(params[:financial_account_id])
    result = Financial::Loans::PlanInstallmentService.call(installment: installment, plan: plan, source_account: source_account)
    redirect_to finance_loan_path(@loan), notice: ("Installment added to plan" if result.success?), alert: (result.error_message unless result.success?)
  end

  private

  def set_loan
    @loan = Financial::Loan.for_account(Current.account).find(params[:id])
  end

  def loan_params
    params.expect(financial_loan: [
      :name, :lender_name, :principal_amount, :interest_rate, :number_of_payments,
      :payment_frequency, :payment_amount, :final_payment_amount, :repayment_basis,
      :interest_category_id, :liability_id, :destination_asset_id,
      :destination_liability_id, :notes
    ])
  end

  def load_collections
    @liabilities = Financial::Liability.for_account(Current.account).active.order(:name)
    @assets = Financial::Asset.for_account(Current.account).active.order(:name)
    @categories = Category.for_account(Current.account).order(:name)
    @plans = Financial::Plan.for_account(Current.account).where(lifecycle_status: %w[draft active]).chronological
  end

  def schedule_start_date
    first_due_date = @loan.installments.minimum(:due_date)
    return Date.current unless first_due_date

    case @loan.payment_frequency
    when "weekly" then first_due_date - 1.week
    when "biweekly" then first_due_date - 2.weeks
    when "quincenal" then first_due_date - 15.days
    else first_due_date.prev_month
    end
  end
end
