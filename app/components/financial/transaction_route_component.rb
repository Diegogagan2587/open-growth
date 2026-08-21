# frozen_string_literal: true

class Financial::TransactionRouteComponent < ViewComponent::Base
  def initialize(transaction:, detailed: false)
    @transaction = transaction
    @detailed = detailed
  end

  def endpoints
    [account_endpoint("Source", @transaction.routed_source_account), account_endpoint("Destination", @transaction.routed_destination_account)].compact
  end

  def detailed? = @detailed

  private

  def account_endpoint(role, account)
    return unless account

    { role: role, kind: account.account_group.humanize, name: account.name, path: helpers.finance_account_path(account) }
  end
end
