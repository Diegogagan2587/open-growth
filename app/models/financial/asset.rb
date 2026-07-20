class Financial::Asset < ApplicationRecord
  self.table_name = "financial_accounts"

  ACCOUNT_TYPES = %w[debit checking savings].freeze
  STATUSES = %w[active closed archived].freeze

  belongs_to :account, class_name: "::Account"
  has_many :financial_entries, class_name: "Financial::Entry", foreign_key: :financial_account_id, dependent: :restrict_with_error, inverse_of: :financial_account
  has_many :incoming_transfers, class_name: "Financial::Entry", foreign_key: :counterparty_financial_account_id, dependent: :restrict_with_error, inverse_of: :counterparty_financial_account

  before_validation :set_account, on: :create

  scope :for_account, ->(account) { where(account: account) }
  scope :active, -> { where(status: "active") }

  validates :name, presence: true, uniqueness: { scope: :account_id }
  validates :account_type, presence: true, inclusion: { in: ACCOUNT_TYPES }
  validates :status, presence: true, inclusion: { in: STATUSES }
  validates :opening_balance, numericality: true

  def current_balance
    entries = Financial::Entry.for_account(account).where(
      "financial_account_id = :id OR counterparty_financial_account_id = :id",
      id: id
    )

    opening_balance.to_d + entries.sum { |entry| entry.account_delta_for(id) }
  end

  def archived?
    status == "archived"
  end

  private

  def set_account
    self.account ||= Current.account if Current.account
  end
end
