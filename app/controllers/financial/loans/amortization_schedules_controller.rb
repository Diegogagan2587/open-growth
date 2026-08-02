class Financial::Loans::AmortizationSchedulesController < ApplicationController
  def show
    loan = Financial::Loan.for_account(Current.account).find(params[:loan_id])
    render json: Financial::Loan::AmortizationSchedule.for(loan, start_date: params[:start_date] || Date.current)
  end

  def create
    loan = Financial::Loan.for_account(Current.account).find(params[:loan_id])
    result = Financial::Loans::GenerateInstallmentsService.call(loan: loan, start_date: params[:start_date])
    redirect_to finance_loan_path(loan), notice: ("Installments generated" if result.success?), alert: (result.error_message unless result.success?)
  end
end
