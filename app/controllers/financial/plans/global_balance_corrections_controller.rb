class Financial::Plans::GlobalBalanceCorrectionsController < ApplicationController
  def update
    plan = Financial::Plan.for_account(Current.account).find(params[:plan_id])
    plan.set_global_balance_checkpoint!(correction_params[:global_balance_override])

    redirect_to finance_plans_path(**filter_params), status: :see_other, notice: "Global balance correction saved"
  rescue ActiveRecord::RecordInvalid => error
    redirect_to finance_plans_path(**filter_params), status: :see_other, alert: error.record.errors.full_messages.to_sentence
  end

  private

  def correction_params
    params.expect(financial_plan: [ :global_balance_override ])
  end

  def filter_params
    params.permit(:budget_period_id, :month, :status).to_h.symbolize_keys
  end
end
