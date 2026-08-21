class Financial::Transactions::ReconciliationsController < ApplicationController
  def create
    transaction = Financial::Transaction.for_account(Current.account).find(params[:transaction_id])
    transaction.reconcile!
    redirect_back fallback_location: finance_transaction_path(transaction), notice: "Transaction reconciled"
  end

  def destroy
    transaction = Financial::Transaction.for_account(Current.account).find(params[:transaction_id])
    transaction.unreconcile!
    redirect_back fallback_location: finance_transaction_path(transaction), notice: "Transaction marked unreconciled"
  end
end
