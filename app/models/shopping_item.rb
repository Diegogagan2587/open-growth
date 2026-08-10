class ShoppingItem < ApplicationRecord
  belongs_to :account
  belongs_to :category, optional: true
  belongs_to :planned_transaction, class_name: "Financial::PlannedTransaction", optional: true
  belongs_to :expense, optional: true
  belongs_to :financial_entry, class_name: "Financial::Entry", optional: true

  before_validation :set_account, on: :create

  scope :for_account, ->(account) { where(account: account) }
  scope :pending, -> { where(status: "pending") }
  scope :purchased, -> { where(status: "purchased") }
  scope :one_time, -> { where(item_type: "one_time") }
  scope :recurring, -> { where(item_type: "recurring") }

  validates :name, presence: true
  validates :status, presence: true, inclusion: { in: %w[pending purchased] }
  validates :item_type, presence: true, inclusion: { in: %w[one_time recurring] }
  validates :estimated_amount, numericality: { greater_than: 0 }, allow_nil: true

  def mark_as_purchased!
    update!(
      status: "purchased",
      last_purchased_at: Date.current
    )
  end

  def convert_to_planned_expense(income_event)
    return nil unless estimated_amount.present? && estimated_amount > 0

    planned_expense = Financial::PlannedTransaction.create!(
      plan: income_event.becomes(Financial::Plan),
      category: category || Category.for_account(account).first,
      description: name,
      amount: estimated_amount,
      status: "pending_to_pay",
      account_id: account_id,
      shopping_item_id: id
    )

    update!(planned_expense_id: planned_expense.id)
    planned_expense
  end

  def convert_to_expense(budget_period, financial_account:)
    return nil unless estimated_amount.present? && estimated_amount > 0
    return nil unless financial_account&.account_id == account_id

    entry = Financial::Entry.create!(
      account: account,
      budget_period: budget_period,
      category: category || Category.for_account(account).first,
      description: name,
      amount: estimated_amount,
      entry_date: Date.current,
      entry_type: "outflow",
      financial_account: financial_account
    )

    update!(financial_entry: entry)
    entry
  end

  def link_to_planned_expense(planned_expense)
    update!(planned_expense_id: planned_expense.id)
    planned_expense.update!(shopping_item_id: id) if planned_expense.respond_to?(:shopping_item_id=)
    planned_expense
  end

  private

  def set_account
    self.account ||= Current.account if Current.account
  end
end
