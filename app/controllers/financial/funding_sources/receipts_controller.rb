class Financial::FundingSources::ReceiptsController < ApplicationController
  def create
    source = Financial::FundingSource.where(account: Current.account).find(params[:funding_source_id])
    result = Financial::FundingSources::Receipt.create(
      funding_source: source,
      amount: params.dig(:funding_source, :amount),
      transaction_date: params.dig(:funding_source, :transaction_date) || params.dig(:funding_source, :entry_date),
      description: params.dig(:funding_source, :description)
    )
    redirect_to finance_plan_path(source.financial_plan), notice: ("Funding received" if result.success?), alert: (result.error_message unless result.success?)
  end

  def destroy
    source = Financial::FundingSource.where(account: Current.account).find(params[:funding_source_id])
    result = Financial::FundingSources::Receipt.destroy(funding_source: source)
    redirect_to finance_plan_path(source.financial_plan), notice: ("Receipt removed" if result.success?), alert: (result.error_message unless result.success?)
  end
end
