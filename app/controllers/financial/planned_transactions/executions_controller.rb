class Financial::PlannedTransactions::ExecutionsController < ApplicationController
  def create
    planned = Financial::PlannedTransaction.for_account(Current.account).find(params[:planned_transaction_id])
    attrs = params.fetch(:planned_transaction, {}).permit(:amount, :interest_amount, :transaction_date, :entry_date, :description, :category_id, :source_account_id, :destination_account_id).to_h.symbolize_keys
    attrs[:transaction_date] ||= attrs.delete(:entry_date)
    result = Financial::PlannedTransactions::Execution.create(planned_transaction: planned, attributes: attrs)
    redirect_back fallback_location: finance_planned_transactions_path, notice: ("Transaction executed" if result.success?), alert: (result.error_message unless result.success?)
  end

  def destroy
    planned = Financial::PlannedTransaction.for_account(Current.account).find(params[:planned_transaction_id])
    result = Financial::PlannedTransactions::Execution.destroy(planned_transaction: planned)
    redirect_back fallback_location: finance_planned_transactions_path, notice: ("Execution removed" if result.success?), alert: (result.error_message unless result.success?)
  end
end
