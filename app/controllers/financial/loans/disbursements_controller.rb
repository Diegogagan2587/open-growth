class Financial::Loans::DisbursementsController < ApplicationController
  def create
    loan = Financial::Loan.for_account(Current.account).find(params[:loan_id])
    plan = Financial::Plan.for_account(Current.account).find(params[:plan_id])
    result = Financial::Loan::Disbursement.create(loan: loan, plan: plan)
    redirect_to finance_loan_path(loan), notice: ("Loan disbursed and activated" if result.success?), alert: (result.error_message unless result.success?)
  end

  def destroy
    loan = Financial::Loan.for_account(Current.account).find(params[:loan_id])
    result = Financial::Loan::Disbursement.destroy(loan: loan)
    redirect_to finance_loan_path(loan), notice: ("Disbursement removed" if result.success?), alert: (result.error_message unless result.success?)
  end
end
