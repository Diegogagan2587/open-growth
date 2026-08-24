class Financial::Loans::SchedulesController < ApplicationController
  def create
    loan = Financial::Loan.for_account(Current.account).find(params[:loan_id])
    result = Financial::Loans::RegenerateSchedule.call(
      loan: loan,
      first_payment_date: params[:first_payment_date].presence || params[:start_date],
      reset_manual_installment_ids: params[:reset_manual_installment_ids]
    )

    redirect_to finance_loan_path(loan),
      notice: ("Schedule regenerated and pending plans synchronized" if result.success?),
      alert: (result.error_message unless result.success?)
  end
end
