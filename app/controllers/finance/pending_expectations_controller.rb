class Finance::PendingExpectationsController < ApplicationController
  MOVEMENT_TYPES = %w[inflow outflow liability_charge transfer liability_payment].freeze

  def index
    @assets = Financial::Asset.for_account(Current.account).active.order(:name)
    @liabilities = Financial::Liability.for_account(Current.account).active.order(:name)
    @movement_type = params[:movement_type] if params[:movement_type].in?(MOVEMENT_TYPES)
    @date_from = parsed_date(:date_from)
    @date_to = parsed_date(:date_to)
    @account_ref = valid_account_ref

    @pending_expectations = funding_sources.map { |source| expectation_for(source) }
    @pending_expectations.concat(planned_transactions.map { |transaction| expectation_for(transaction) })
    @pending_expectations.sort_by! { |expectation| [ expectation[:date] || Date.new(9999, 12, 31), expectation[:record].id ] }
  end

  private

  def funding_sources
    scope = Financial::FundingSource.where(account: Current.account)
      .joins(:financial_plan)
      .left_joins(:receipt_entry)
      .where(resolution: "pending", financial_entries: { id: nil })
      .where.not(kind: "borrowed")
      .where(income_events: { lifecycle_status: %w[draft active] })
      .includes(:financial_plan, :expected_destination_asset, :expected_destination_liability)
    scope = scope.where(expected_date: @date_from..) if @date_from
    scope = scope.where(expected_date: ..@date_to) if @date_to
    scope = scope.none if @movement_type.present? && @movement_type != "inflow"
    filter_funding_sources_by_account(scope)
  end

  def planned_transactions
    scope = Financial::PlannedTransaction.for_account(Current.account)
      .left_joins(:financial_entry, :income_event)
      .where(execution_status: "pending", financial_entries: { id: nil })
      .where("income_events.id IS NULL OR income_events.lifecycle_status IN (?)", %w[draft active])
      .includes(:plan, :financial_account, :counterparty_financial_account, :financial_liability)
    scope = scope.where(kind: @movement_type) if @movement_type.present?
    scope = scope.where(planned_for: @date_from..) if @date_from
    scope = scope.where(planned_for: ..@date_to) if @date_to
    filter_planned_transactions_by_account(scope)
  end

  def filter_funding_sources_by_account(scope)
    kind, id = @account_ref.to_s.split(":", 2)
    return scope.where(expected_destination_asset_id: id) if kind == "asset"
    return scope.where(expected_destination_liability_id: id) if kind == "liability"

    scope
  end

  def filter_planned_transactions_by_account(scope)
    kind, id = @account_ref.to_s.split(":", 2)
    return scope.where("financial_account_id = :id OR counterparty_financial_account_id = :id", id: id) if kind == "asset"
    return scope.where(financial_liability_id: id) if kind == "liability"

    scope
  end

  def expectation_for(record)
    if record.is_a?(Financial::FundingSource)
      {
        record: record,
        date: record.expected_date,
        amount: record.expected_amount,
        type: "inflow",
        plan: record.financial_plan,
        route: record.expected_destination_asset&.name || record.expected_destination_liability&.name || "No destination"
      }
    else
      {
        record: record,
        date: record.planned_for || record.due_date || record.plan&.planned_for,
        amount: record.amount,
        type: record.kind,
        plan: record.plan,
        route: record.routing_summary || "No account assigned"
      }
    end
  end

  def parsed_date(key)
    Date.iso8601(params[key]) if params[key].present?
  rescue Date::Error
    nil
  end

  def valid_account_ref
    kind, id = params[:account_ref].to_s.split(":", 2)
    return "asset:#{id}" if kind == "asset" && @assets.exists?(id)

    "liability:#{id}" if kind == "liability" && @liabilities.exists?(id)
  end
end
