class Financial::FundingSourcesController < ApplicationController
  before_action :set_plan
  before_action :set_funding_source, only: [ :update, :destroy, :receive ]

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
      redirect_to finance_plan_path(@plan), notice: "Funding source updated"
    else
      redirect_to finance_plan_path(@plan), alert: @funding_source.errors.full_messages.to_sentence
    end
  end

  def destroy
    if @funding_source.destroy
      redirect_to finance_plan_path(@plan), notice: "Funding source removed"
    else
      redirect_to finance_plan_path(@plan), alert: @funding_source.errors.full_messages.to_sentence
    end
  end

  def receive
    result = Financial::FundingSources::ReceiveService.call(
      funding_source: @funding_source,
      amount: params.dig(:funding_source, :amount),
      entry_date: params.dig(:funding_source, :entry_date),
      description: params.dig(:funding_source, :description)
    )
    if result.success?
      redirect_back fallback_location: finance_plan_path(@plan), notice: "Funding received"
    else
      redirect_back fallback_location: finance_plan_path(@plan), alert: result.error_message
    end
  end

  private

  def set_plan
    @plan = Financial::Plan.for_account(Current.account).find(params[:plan_id])
  end

  def set_funding_source
    @funding_source = @plan.funding_sources.find(params[:id])
  end

  def funding_source_params
    params.expect(funding_source: [
      :description,
      :expected_amount,
      :expected_date,
      :kind,
      :resolution,
      :expected_destination_asset_id,
      :expected_destination_liability_id
    ])
  end
end
