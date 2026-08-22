# frozen_string_literal: true

# Compatibility wrapper. New code should use Financial::Account directly.
class Financial::Liability < Financial::Account
  LIABILITY_TYPES = %w[credit_card personal_credit].freeze
  default_scope { where(account_group: "liability") }
  has_many :financial_entries, class_name: "Financial::Entry", foreign_key: :financial_liability_id,
    dependent: :restrict_with_error, inverse_of: :financial_liability
  has_many :incoming_financial_entries, class_name: "Financial::Entry", foreign_key: :counterparty_financial_liability_id,
    dependent: :restrict_with_error, inverse_of: :counterparty_financial_liability

  validates :account_type, inclusion: { in: LIABILITY_TYPES }

  def current_balance
    entries = Financial::Entry.for_account(account).where(
      "financial_liability_id = :id OR counterparty_financial_liability_id = :id",
      id: id
    )
    opening_balance.to_d + entries.sum { |entry| entry.liability_delta_for(id) }
  end

  def settle_and_archive!
    update!(status: "archived", archived_at: Time.current)
  end
end
