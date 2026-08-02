class Financial::Plans::CancellationsController < ApplicationController
  def create
    plan = Financial::Plan.for_account(Current.account).find(params[:plan_id])
    plan.update!(lifecycle_status: "cancelled")
    redirect_to finance_plan_path(plan), notice: "Plan cancelled"
  end
end
