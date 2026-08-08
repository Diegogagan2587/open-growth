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

  def account_endpoint(role, account)
    endpoint(role, account.account_group.humanize, account, helpers.finance_account_path(account)) if account
  end

  def endpoint(role, kind, record, path)
    { role: role, kind: kind, name: record.try(:name).presence || record.description, path: path }
  end
end
