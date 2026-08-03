class Financial::Loans::SchedulesController < ApplicationController
  def create
    loan = Financial::Loan.for_account(Current.account).find(params[:loan_id])
    result = Financial::Loans::RegenerateSchedule.call(loan: loan, start_date: params[:start_date])

    redirect_to finance_loan_path(loan),
      notice: ("Schedule regenerated and pending plans synchronized" if result.success?),
      alert: (result.error_message unless result.success?)
  end
end
