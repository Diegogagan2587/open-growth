class Financial::Account < ApplicationRecord
  self.table_name = "financial_accounts"

  ACCOUNT_GROUPS = %w[asset liability].freeze
  ACCOUNT_TYPES = %w[debit checking savings credit_card personal_credit].freeze
  STATUSES = %w[active closed archived].freeze

  belongs_to :account, class_name: "::Account"
  has_many :outgoing_transactions,
    class_name: "Financial::Transaction",
    foreign_key: :source_account_id,
    dependent: :restrict_with_error,
    inverse_of: :source_account
  has_many :incoming_transactions,
    class_name: "Financial::Transaction",
    foreign_key: :destination_account_id,
    dependent: :restrict_with_error,
    inverse_of: :destination_account

  before_validation :set_owner_account, on: :create

  scope :for_account, ->(account) { where(account: account) }
  scope :active, -> { where(status: "active") }
  scope :assets, -> { where(account_group: "asset") }
  scope :liabilities, -> { where(account_group: "liability") }

  validates :name, presence: true, uniqueness: { scope: %i[account_id account_group] }
  validates :account_group, inclusion: { in: ACCOUNT_GROUPS }
  validates :account_type, inclusion: { in: ACCOUNT_TYPES }
  validates :status, inclusion: { in: STATUSES }
  validates :opening_balance, numericality: true
  validates :credit_limit, numericality: { greater_than: 0 }, allow_nil: true
  validate :account_type_matches_group

  def current_balance
    transactions.sum(opening_balance.to_d) { |transaction| transaction.account_delta_for(id) }
  end

  def transactions
    Financial::Transaction.for_account(account)
      .where("source_account_id = :id OR destination_account_id = :id", id: id)
  end

  def asset?
    account_group == "asset"
  end

  def liability?
    account_group == "liability"
  end

  def archived?
    status == "archived"
  end

  def archive!
    update!(status: "archived", archived_at: Time.current)
  end

  alias_method :settle_and_archive!, :archive!

  private

  def set_owner_account
    self.account ||= Current.account if Current.account
  end

  def account_type_matches_group
    allowed = asset? ? %w[debit checking savings] : %w[credit_card personal_credit]
    errors.add(:account_type, "does not belong to this account group") unless account_type.in?(allowed)
  end
end
