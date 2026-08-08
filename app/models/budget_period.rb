class BudgetPeriod < ApplicationRecord
  belongs_to :account
  has_many :income_events, dependent: :nullify
  has_many :financial_plans, class_name: "Financial::Plan", dependent: :nullify
  has_many :financial_planned_transactions, through: :financial_plans, source: :planned_transactions
  has_many :planned_expenses, through: :income_events
  has_many :financial_budget_allocations, class_name: "Financial::BudgetAllocation", dependent: :destroy
  has_many :expenses, dependent: :nullify

  before_validation :set_account, on: :create

  scope :for_account, ->(account) { where(account: account) }

  def total_income
    financial_plans.sum { |plan| plan.funding_sources.sum { |source| source.actual_amount || source.expected_amount } }
  end

  def total_planned
    planned_expenses.budget_consuming.sum(:amount)
  end

  def remaining_budget
    total_income - total_planned
  end

  def income_events_ordered
    income_events.order(:expected_date)
  end

  private

  def set_account
    self.account ||= Current.account if Current.account
  end
end
