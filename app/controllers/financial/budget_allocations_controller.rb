class Financial::BudgetAllocationsController < ApplicationController
  before_action :set_budget_period
  before_action :set_allocation, only: %i[update destroy]

  def create
    allocation = @budget_period.financial_budget_allocations.new(allocation_params.merge(account: Current.account))
    if allocation.save
      redirect_to budget_period_path(@budget_period), notice: "Budget allocation added"
    else
      redirect_to budget_period_path(@budget_period), alert: allocation.errors.full_messages.to_sentence
    end
  end

  def update
    if @allocation.update(allocation_params)
      redirect_to budget_period_path(@budget_period), notice: "Budget allocation updated"
    else
      redirect_to budget_period_path(@budget_period), alert: @allocation.errors.full_messages.to_sentence
    end
  end

  def destroy
    @allocation.destroy!
    redirect_to budget_period_path(@budget_period), status: :see_other, notice: "Budget allocation removed"
  end

  private

  def set_budget_period
    @budget_period = BudgetPeriod.for_account(Current.account).find(params[:budget_period_id])
  end

  def set_allocation
    @allocation = @budget_period.financial_budget_allocations.find(params[:id])
  end

  def allocation_params
    params.expect(financial_budget_allocation: %i[category_id planned_amount])
  end
end
