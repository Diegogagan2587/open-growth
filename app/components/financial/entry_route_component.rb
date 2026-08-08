# frozen_string_literal: true

class Financial::EntryRouteComponent < ViewComponent::Base
  def initialize(entry:, detailed: false)
    @entry = entry
    @detailed = detailed
  end

  def endpoints
    [ source, destination ].compact
  end

  def detailed?
    @detailed
  end

  private

  def source
    account_endpoint("Source", @entry.routed_source_account)
  end

  def destination
    account_endpoint("Destination", @entry.routed_destination_account)
  end

  def asset_endpoint(role, asset)
    endpoint(role, "Asset", asset, helpers.finance_financial_account_path(asset)) if asset
  end

  def liability_endpoint(role, liability)
    endpoint(role, "Liability", liability, helpers.finance_financial_liability_path(liability)) if liability
  end

  def income_event_endpoint(role, income_event)
    endpoint(role, "Financial plan", income_event, helpers.finance_plan_path(income_event)) if income_event
  end

  def endpoint(role, kind, record, path)
    { role: role, kind: kind, name: record.try(:name).presence || record.description, path: path }
  end
end
