class Financial::Plans::ClosuresController < ApplicationController
  def create
    plan = Financial::Plan.for_account(Current.account).find(params[:plan_id])
    result = Financial::Plans::CloseService.call(plan: plan)
    redirect_to finance_plan_path(plan), notice: ("Plan closed" if result.success?), alert: (result.error_message unless result.success?)
  end
end
