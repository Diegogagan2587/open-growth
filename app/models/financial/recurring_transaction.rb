class Financial::RecurringTransaction < ApplicationRecord
  self.table_name = "financial_recurring_transactions"

  FREQUENCIES = %w[weekly biweekly quincenal monthly bimonthly quarterly custom].freeze
  STATUSES = %w[active archived].freeze

  belongs_to :account, class_name: "::Account"
  belongs_to :category, optional: true
  belongs_to :source_account, class_name: "Financial::Account", optional: true
  belongs_to :destination_account, class_name: "Financial::Account", optional: true
  has_many :planned_transactions,
    class_name: "Financial::PlannedTransaction",
    inverse_of: :recurring_transaction,
    dependent: :restrict_with_error
  has_many :planned_expenses,
    class_name: "::PlannedExpense",
    foreign_key: :expense_template_id,
    dependent: :restrict_with_error

  before_validation :set_owner_account, on: :create
  before_validation :set_transaction_kind_default, on: :create
  before_validation :set_budget_consuming_default, on: :create

  scope :for_account, ->(account) { where(account: account) }
  scope :active, -> { where(status: "active") }
  scope :ordered, -> { order(:name) }

  validates :name, presence: true
  validates :amount, numericality: { greater_than: 0 }
  validates :frequency, inclusion: { in: FREQUENCIES }
  validates :transaction_kind, inclusion: { in: Financial::PlannedTransaction::KINDS }
  validates :importance, inclusion: { in: Financial::PlannedTransaction::IMPORTANCES }
  validates :status, inclusion: { in: STATUSES }
  validates :category, presence: true, if: :budget_consuming?
  validate :route_is_valid
  validate :associations_belong_to_same_account

  alias_attribute :total_amount, :amount

  def build_occurrence(plan:, planned_execution_date: nil)
    planned_transactions.build(
      account: account,
      plan: plan,
      category: category,
      source_account: source_account,
      destination_account: destination_account,
      description: description.presence || name,
      planned_amount: amount,
      planned_execution_date: planned_execution_date.presence || plan&.planned_for,
      kind: transaction_kind,
      importance: importance,
      execution_status: "pending",
      budget_consuming: budget_consuming
    )
  end

  def budget_consuming?
    self[:budget_consuming]
  end

  def routing_summary
    account_route.routing_summary
  end

  private

  def set_owner_account
    self.account ||= Current.account if Current.account
  end

  def set_budget_consuming_default
    self.budget_consuming = account_route.budget_consuming? if budget_consuming.nil?
  end

  def infer_transaction_kind
    return if transaction_kind.present? && !new_record? && !will_save_change_to_source_account_id? && !will_save_change_to_destination_account_id?
    return if transaction_kind.present? && source_account.blank? && destination_account.blank?

    self.transaction_kind = account_route.kind
  end

  def route_is_valid
    account_route.validation_errors.each do |attribute, messages|
      messages.each { |message| errors.add(attribute, message) }
    end
  end

  def account_route
    Financial::Transactions::AccountRoute.for_planning(source: source_account, destination: destination_account, kind: transaction_kind)
  end

  def associations_belong_to_same_account
    return if account.blank?

    %i[category source_account destination_account].each do |association|
      record = public_send(association)
      errors.add(association, "must belong to the current account") if record && record.account_id != account_id
    end
  end
end
