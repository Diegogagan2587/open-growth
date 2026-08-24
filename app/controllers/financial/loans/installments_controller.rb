class Financial::Loans::InstallmentsController < ApplicationController
  def update
    loan = Financial::Loan.for_account(Current.account).find(params[:loan_id])
    installment = loan.installments.find(params[:id])
    result = Financial::Loans::UpdateInstallmentDueDate.call(
      installment: installment,
      due_date: installment_params[:due_date],
      update_planned_transaction: installment_params[:update_planned_transaction],
      expected_updated_at: installment_params[:expected_updated_at]
    )

    redirect_to finance_loan_path(loan),
      notice: ("Installment due date updated" if result.success?),
      alert: (result.error_message unless result.success?)
  end

  private

  def installment_params
    params.expect(installment: [ :due_date, :update_planned_transaction, :expected_updated_at ])
  end
end
