class Financial::Liability < ApplicationRecord
  self.table_name = "financial_liabilities"

  LIABILITY_TYPES = %w[credit_card personal_credit].freeze
  STATUSES = %w[active closed archived].freeze

  belongs_to :account, class_name: "::Account"
  has_many :financial_entries, class_name: "Financial::Entry", foreign_key: :financial_liability_id, dependent: :restrict_with_error, inverse_of: :financial_liability
  has_many :incoming_financial_entries, class_name: "Financial::Entry", foreign_key: :counterparty_financial_liability_id, dependent: :restrict_with_error, inverse_of: :counterparty_financial_liability

  before_validation :set_account, on: :create

  scope :for_account, ->(account) { where(account: account) }
  scope :active, -> { where(status: "active") }

  validates :name, presence: true, uniqueness: { scope: :account_id }
  validates :liability_type, presence: true, inclusion: { in: LIABILITY_TYPES }
  validates :status, presence: true, inclusion: { in: STATUSES }
  validates :opening_balance, numericality: true
  validates :credit_limit, numericality: { greater_than: 0 }, allow_nil: true

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

  private

  def set_account
    self.account ||= Current.account if Current.account
  end
end
