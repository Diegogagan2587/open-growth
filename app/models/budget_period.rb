class BudgetPeriod < ApplicationRecord
  belongs_to :account
  has_many :income_events, dependent: :nullify
  has_many :planned_expenses, through: :income_events
  has_many :budget_line_items, dependent: :destroy
  has_many :expenses, dependent: :nullify

  before_validation :set_account, on: :create

  scope :for_account, ->(account) { where(account: account) }

  def total_income
    income_events.sum { |ie| ie.received_amount || ie.expected_amount }
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
