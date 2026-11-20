class Financial::FundingSources::PlanAssignmentsController < ApplicationController
  def update
    plan = Financial::Plan.for_account(Current.account).find(params[:plan_id])
    funding_source = plan.funding_sources.find(params[:funding_source_id])
    target_plan = Financial::Plan.for_account(Current.account).find_by(id: params[:target_plan_id])

    if funding_source.move_to(target_plan)
      redirect_to finance_plan_path(target_plan), notice: "Funding source moved"
    else
      redirect_to finance_plan_path(plan), alert: funding_source.errors.full_messages.to_sentence
    end
  end
end
