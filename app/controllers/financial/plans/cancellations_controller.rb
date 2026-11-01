class Financial::Plans::CancellationsController < ApplicationController
  before_action :set_plan

  def create
    if @plan.cancel!
      redirect_to finance_plan_path(@plan), notice: "Plan cancelled"
    else
      redirect_to finance_plan_path(@plan), alert: "Only draft or active plans can be cancelled"
    end
  end

  def destroy
    if @plan.restore!
      redirect_to finance_plan_path(@plan), notice: "Plan restored"
    else
      redirect_to finance_plan_path(@plan), alert: "Only cancelled plans can be restored"
    end
  end

  private

  def set_plan
    @plan = Financial::Plan.for_account(Current.account).find(params[:plan_id])
  end
end
