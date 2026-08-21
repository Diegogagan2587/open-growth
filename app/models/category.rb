class Category < ApplicationRecord
  belongs_to :account
  has_many :financial_transactions, class_name: "Financial::Transaction", dependent: :restrict_with_error
  has_many :financial_savings_goals, class_name: "Financial::SavingsGoal", dependent: :destroy
  has_many :financial_recurring_transactions, class_name: "Financial::RecurringTransaction", dependent: :restrict_with_error
  has_many :expenses, dependent: :destroy
  has_many :financial_budget_allocations, class_name: "Financial::BudgetAllocation", dependent: :destroy
  has_many :planned_expenses, dependent: :destroy
  has_many :shopping_items, dependent: :destroy
  has_many :inventory_items, dependent: :destroy

  validates :name, presence: true
  validates :name, uniqueness: { scope: :account_id }

  before_validation :set_account, on: :create

  scope :for_account, ->(account) { where(account: account) }

  private

  def set_account
    self.account ||= Current.account if Current.account
  end
end
