class Financial::FundingSourcesController < ApplicationController
  before_action :set_plan, only: :create
  before_action :set_funding_source, only: %i[update destroy receive]

  def create
    source = @plan.funding_sources.new(funding_source_params.merge(account: Current.account))
    if source.save
      redirect_to finance_plan_path(@plan), notice: "Funding source added"
    else
      redirect_to finance_plan_path(@plan), alert: source.errors.full_messages.to_sentence
    end
  end

  def update
    if @funding_source.update(funding_source_params)
      redirect_to finance_plan_path(@funding_source.financial_plan), notice: "Funding source updated"
    else
      redirect_to finance_plan_path(@funding_source.financial_plan), alert: @funding_source.errors.full_messages.to_sentence
    end
  end

  def destroy
    plan = @funding_source.financial_plan
    if @funding_source.destroy
      redirect_to finance_plan_path(plan), notice: "Funding source removed"
    else
      redirect_to finance_plan_path(plan), alert: @funding_source.errors.full_messages.to_sentence
    end
  end

  def receive
    result = Financial::FundingSources::Receipt.create(
      funding_source: @funding_source,
      amount: params.dig(:funding_source, :amount),
      transaction_date: params.dig(:funding_source, :transaction_date) || params.dig(:funding_source, :entry_date),
      description: params.dig(:funding_source, :description)
    )
    if result.success?
      redirect_back fallback_location: finance_plan_path(@funding_source.financial_plan), notice: "Funding received"
    else
      redirect_back fallback_location: finance_plan_path(@funding_source.financial_plan), alert: result.error_message
    end
  end

  private

  def set_plan
    @plan = Financial::Plan.for_account(Current.account).find(params[:plan_id])
  end

  def set_funding_source
    @funding_source = Financial::FundingSource.where(account: Current.account).find(params[:id])
  end

  def funding_source_params
    params.expect(funding_source: %i[description expected_amount expected_date kind resolution expected_destination_account_id])
  end
end
