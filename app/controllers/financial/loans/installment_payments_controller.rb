class Financial::Loans::InstallmentPaymentsController < ApplicationController
  def create
    loan = Financial::Loan.for_account(Current.account).find(params[:loan_id])
    installment = loan.installments.find(params[:installment_id])
    result = Financial::Loans::ApplyInstallmentPayment.call(
      installment: installment,
      total: payment_params[:total],
      interest: payment_params[:interest],
      entry_date: payment_params[:entry_date]
    )

    redirect_back fallback_location: finance_loan_path(loan),
      notice: ("Installment payment recorded" if result.success?),
      alert: (result.error_message unless result.success?)
  end

  private

  def payment_params
    params.expect(installment_payment: [ :total, :interest, :entry_date ])
  end
end
