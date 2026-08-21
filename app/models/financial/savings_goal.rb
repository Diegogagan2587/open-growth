class Financial::SavingsGoal < ApplicationRecord
  self.table_name = "financial_savings_goals"

  belongs_to :account, class_name: "::Account"
  belongs_to :category
  has_many :planned_transactions, class_name: "Financial::PlannedTransaction", dependent: :nullify

  before_validation :set_owner_account, on: :create

  scope :for_account, ->(account) { where(account: account) }

  validates :name, presence: true
  validates :total_amount, numericality: { greater_than: 0 }
  validates :frequency, inclusion: { in: %w[weekly biweekly monthly bimonthly quarterly custom] }
  validate :category_belongs_to_same_account

  def total_saved
    Financial::Transaction.where(planned_transaction_id: planned_transactions.select(:id)).sum(:amount)
  end

  alias_method :total_applied, :total_saved

  def progress_percentage
    return 0 if total_amount.zero?

    (total_saved / total_amount) * 100
  end

  def remaining_amount
    total_amount - total_saved
  end

  def complete?
    total_saved >= total_amount
  end

  alias_method :is_complete?, :complete?

  private

  def set_owner_account
    self.account ||= Current.account if Current.account
  end

  def category_belongs_to_same_account
    errors.add(:category, "must belong to the current account") if category && category.account_id != account_id
  end
end
