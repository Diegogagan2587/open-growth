class Financial::Loans::InstallmentsController < ApplicationController
  def update
    loan, installment = loan_and_installment
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

  def destroy_history
    loan, installment = loan_and_installment
    if installment.remove_paid_history
      redirect_to finance_loan_path(loan), status: :see_other, notice: "Installment payment and plan records deleted"
    else
      redirect_to finance_loan_path(loan), alert: installment.errors.full_messages.to_sentence
    end
  end

  private

  def loan_and_installment
    loan = Financial::Loan.for_account(Current.account).find(params[:loan_id])
    [ loan, loan.installments.find(params[:id]) ]
  end

  def installment_params
    params.expect(installment: [ :due_date, :update_planned_transaction, :expected_updated_at ])
  end
end
