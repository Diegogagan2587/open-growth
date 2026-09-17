class Financial::Loans::InstallmentPlansController < ApplicationController
  before_action :set_loan_and_installment

  def create
    plan = Financial::Plan.for_account(Current.account).find(params[:plan_id])
    source_account = Financial::Asset.for_account(Current.account).active.find(params[:financial_account_id])
    result = Financial::Loans::PlanInstallmentService.call(installment: @installment, plan: plan, source_account: source_account)

    redirect_to finance_loan_path(@loan),
      notice: ("Installment added to plan" if result.success?),
      alert: (result.error_message unless result.success?)
  end

  def destroy
    removed = @installment.remove_from_plan
    redirect_to finance_loan_path(@loan),
      notice: ("Planned installment deleted" if removed),
      alert: (@installment.errors.full_messages.to_sentence unless removed)
  end

  private

  def set_loan_and_installment
    @loan = Financial::Loan.for_account(Current.account).find(params[:loan_id])
    @installment = @loan.installments.find(params[:installment_id])
  end
end
