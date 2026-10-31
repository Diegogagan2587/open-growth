class Financial::Plans::PlannedTransactionOrdersController < ApplicationController
  def update
    plan = Financial::Plan.for_account(Current.account).find(params[:plan_id])
    plan.reorder_planned_transactions!(order_params[:ordered_ids])
    redirect_to finance_plan_path(plan, order: "custom"), status: :see_other, notice: "Payment priority updated"
  rescue ActiveRecord::RecordInvalid => error
    redirect_to finance_plan_path(plan), status: :see_other, alert: error.record.errors.full_messages.to_sentence
  end

  private

  def order_params
    params.require(:planned_transaction_order).permit(ordered_ids: [])
  end
end
