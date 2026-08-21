class Financial::BudgetAllocation < ApplicationRecord
  self.table_name = "financial_budget_allocations"

  belongs_to :account, class_name: "::Account"
  belongs_to :budget_period
  belongs_to :category

  before_validation :set_owner_account, on: :create

  scope :for_account, ->(account) { where(account: account) }

  validates :planned_amount, numericality: { greater_than: 0 }
  validates :category_id, uniqueness: { scope: :budget_period_id }
  validate :associations_belong_to_same_account

  private

  def set_owner_account
    self.account ||= Current.account if Current.account
  end

  def associations_belong_to_same_account
    errors.add(:budget_period, "must belong to the current account") if budget_period && budget_period.account_id != account_id
    errors.add(:category, "must belong to the current account") if category && category.account_id != account_id
  end
end
