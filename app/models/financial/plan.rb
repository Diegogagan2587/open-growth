class Financial::Plan < ApplicationRecord
  self.table_name = "financial_plans"

  LIFECYCLE_STATUSES = %w[draft active closed cancelled].freeze

  # Accepted only while older callers are moved off IncomeEvent. A Plan's
  # expected funding is derived from its FundingSources, never from this value.
  attr_writer :expected_amount

  belongs_to :account, class_name: "::Account"
  belongs_to :budget_period, optional: true
  has_many :funding_sources,
    class_name: "Financial::FundingSource",
    foreign_key: :financial_plan_id,
    inverse_of: :financial_plan,
    dependent: :destroy
  has_many :funding_transactions, through: :funding_sources, source: :receipt_transaction
  has_many :planned_transactions,
    class_name: "Financial::PlannedTransaction",
    inverse_of: :plan,
    dependent: :destroy
  has_many :transactions,
    class_name: "Financial::Transaction",
    inverse_of: :plan,
    dependent: :restrict_with_error

  before_validation :set_owner_account, on: :create
  before_destroy :allow_safe_draft_deletion

  scope :for_account, ->(account) { where(account: account) }
  scope :chronological, -> { order(:planned_for, :id) }

  validates :name, :planned_for, presence: true
  validates :lifecycle_status, inclusion: { in: LIFECYCLE_STATUSES }
  validate :closed_chronology_is_immutable, on: :update
  validate :budget_period_belongs_to_account

  # Compatibility readers for views during the legacy-route retirement window.
  alias_attribute :description, :name
  alias_attribute :expected_date, :planned_for
  alias_method :financial_entries, :transactions
  alias_method :funding_entries, :funding_transactions

  def expected_amount
    @expected_amount || funding_sources.sum(:expected_amount)
  end

  def status
    lifecycle_status
  end

  def status=(value)
    self.lifecycle_status = value == "pending" ? "active" : value
  end

  private

  def set_owner_account
    self.account ||= Current.account if Current.account
  end

  def allow_safe_draft_deletion
    return if lifecycle_status == "draft" && transactions.none? && funding_sources.none?(&:receipt_transaction)

    errors.add(:base, "only an empty draft plan can be deleted; cancel it instead")
    throw :abort
  end

  def closed_chronology_is_immutable
    return unless lifecycle_status.in?(%w[closed cancelled])
    return unless will_save_change_to_planned_for? || will_save_change_to_budget_period_id?

    errors.add(:base, "closed or cancelled plan chronology cannot be changed")
  end

  def budget_period_belongs_to_account
    errors.add(:budget_period, "must belong to the current account") if budget_period && budget_period.account_id != account_id
  end
end
