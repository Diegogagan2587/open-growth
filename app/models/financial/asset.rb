# frozen_string_literal: true

# Compatibility wrapper. New code should use Financial::Account directly.
class Financial::Asset < Financial::Account
  ACCOUNT_TYPES = %w[debit checking savings].freeze
  default_scope { where(account_group: "asset") }
  has_many :incoming_transfers, class_name: "Financial::Entry", foreign_key: :counterparty_financial_account_id,
    dependent: :restrict_with_error, inverse_of: :counterparty_financial_account

  validates :account_type, inclusion: { in: ACCOUNT_TYPES }
end
