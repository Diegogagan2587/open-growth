class PlannedExpense < ApplicationRecord
  FINAL_STATUSES = %w[spent paid transferred].freeze

  attr_accessor :source_selection, :destination_selection

  belongs_to :account
  belongs_to :income_event, optional: true
  belongs_to :origin_income_event, class_name: "IncomeEvent", optional: true
  belongs_to :category, optional: true
  belongs_to :expense_template, optional: true
  belongs_to :shopping_item, optional: true
  belongs_to :financial_account, class_name: "Financial::Asset", optional: true
  belongs_to :counterparty_financial_account, class_name: "Financial::Asset", optional: true
  belongs_to :financial_liability, class_name: "Financial::Liability", optional: true
  has_one :expense, dependent: :nullify
  has_one :financial_entry, class_name: "Financial::Entry", dependent: :nullify

  before_validation :set_account, on: :create
  before_validation :infer_transaction_kind

  scope :for_account, ->(account) { where(account: account) }

  validates :description, presence: true
  validates :income_event, presence: true, unless: :unassigned_planned_transaction?
  validates :amount, presence: true, numericality: { greater_than: 0 }
  validates :status, presence: true
  validates :category, presence: true, if: :budget_consuming?
  validate :financial_routing_is_valid, if: -> {
    source_selection.present? || destination_selection.present? ||
    financial_account_id.present? || counterparty_financial_account_id.present? ||
    financial_liability_id.present?
  }
  validate :planned_values_are_immutable_after_execution, on: :update

  scope :by_position, -> { order(:position, :created_at) }
  scope :by_status, ->(status) { where(status: status) }
  scope :by_template, ->(template_id) { where(expense_template_id: template_id) }
  scope :budget_consuming, -> {
    where(counterparty_financial_account_id: nil)
      .where("financial_account_id IS NULL OR financial_liability_id IS NULL")
  }

  def percentage_of_income
    return 0 unless budget_consuming?
    return 0 if income_event.expected_amount.zero?
    (amount / income_event.expected_amount) * 100
  end

  def source_selection
    @source_selection || selection_for_source
  end

  def source_selection=(value)
    @source_selection = value.presence
    assign_source_selection(value)
  end

  def destination_selection
    @destination_selection || selection_for_destination
  end

  def destination_selection=(value)
    @destination_selection = value.presence
    assign_destination_selection(value)
  end

  def apply!
    result = PlannedExpenses::ExecuteService.call(planned_expense: self)
    raise ActiveRecord::RecordInvalid.new(self) unless result.success?

    result.expense || result.entry
  end

  def self.final_status?(value)
    FINAL_STATUSES.include?(value.to_s)
  end

  def final_status?
    self.class.final_status?(status)
  end

  def transaction_missing?
    final_status? && financial_entry.blank?
  end

  def template_progress
    return nil unless expense_template

    saved = expense_template.total_saved
    total = expense_template.total_amount
    percentage = expense_template.progress_percentage

    {
      saved: saved,
      total: total,
      percentage: percentage,
      remaining: expense_template.remaining_amount,
      complete: expense_template.is_complete?
    }
  end

  private

  def set_account
    self.account ||= Current.account if Current.account
  end

  def infer_transaction_kind
    self.kind ||= if transfer?
      "transfer"
    elsif debt_payment?
      "liability_payment"
    elsif financial_liability_id.present?
      "liability_charge"
    else
      "outflow"
    end
  end

  def unassigned_planned_transaction?
    is_a?(Financial::PlannedTransaction)
  end

  def planned_values_are_immutable_after_execution
    immutable_fields = %w[amount description category_id due_date financial_account_id counterparty_financial_account_id financial_liability_id income_event_id]
    return if (changes.keys & immutable_fields).empty?
    return if financial_entry.blank?

    errors.add(:base, "applied planning values are historical and cannot be changed")
  end

  public

  def routing_summary
    source = financial_account
    destination = counterparty_financial_account
    liability = financial_liability

    if source && destination
      "Transfer from #{source.name} to #{destination.name}"
    elsif source && liability
      "Pay #{liability.name} from #{source.name}"
    elsif liability
      "Charged to #{liability.name}"
    elsif source
      "Pay from #{source.name}"
    end
  end

  def transfer?
    financial_account_id.present? && counterparty_financial_account_id.present?
  end

  def debt_payment?
    financial_account_id.present? && financial_liability_id.present?
  end

  def budget_consuming?
    source_present = financial_account.present?
    destination_present = counterparty_financial_account.present?
    liability_present = financial_liability.present?

    !(source_present && destination_present) && !(source_present && liability_present)
  end

  def reduces_plan_balance?
    budget_consuming? || (debt_payment? && commits_plan_funds?)
  end

  def classification_label
    return category.name if category.present?
    return "Transfer" if transfer?
    return "Card payment" if debt_payment?

    "Uncategorized"
  end

  def movement_label
    debt_payment? ? "Card payment" : "Transfer"
  end

  def financial_account_name
    financial_account&.name || "unassigned account"
  end

  private

  def assign_source_selection(value)
    return clear_source_selection if value.blank?

    kind, id = value.split(":", 2)
    case kind
    when "asset"
      self.financial_account_id = id
      self.financial_liability_id = nil if counterparty_financial_account.blank?
    when "liability"
      self.financial_liability_id = id
      self.financial_account_id = nil if counterparty_financial_account.blank?
    end
  end

  def assign_destination_selection(value)
    return clear_destination_selection if value.blank?

    kind, id = value.split(":", 2)
    case kind
    when "asset"
      self.counterparty_financial_account_id = id
    when "liability"
      self.financial_liability_id = id
    end
  end

  def clear_source_selection
    self.financial_account_id = nil if financial_account_id.blank?
    self.financial_liability_id = nil if financial_liability_id.blank?
  end

  def clear_destination_selection
    self.counterparty_financial_account_id = nil if counterparty_financial_account_id.blank?
    self.financial_liability_id = nil if financial_account.present?
  end

  def selection_for_source
    return "asset:#{financial_account_id}" if financial_account.present?

    return "liability:#{financial_liability_id}" if financial_liability.present? && counterparty_financial_account.blank?

    nil
  end

  def selection_for_destination
    return "asset:#{counterparty_financial_account_id}" if counterparty_financial_account.present?

    return "liability:#{financial_liability_id}" if financial_account.present? && financial_liability.present?

    nil
  end

  def financial_routing_is_valid
    # Require at least one source when any routing information is present
    if financial_account.blank? && financial_liability.blank?
      errors.add(:source_selection, "must be selected")
      return
    end

    if financial_liability.present? && financial_account.blank? && destination_selection.present?
      errors.add(:destination_selection, "must be blank when the source is a liability")
    end

    if financial_account.present? && counterparty_financial_account.present? && financial_account_id == counterparty_financial_account_id
      errors.add(:counterparty_financial_account, "must be different from the source account")
    end

    if financial_account.present? && financial_account.account_id != account_id
      errors.add(:financial_account, "must belong to the current account")
    end

    if counterparty_financial_account.present? && counterparty_financial_account.account_id != account_id
      errors.add(:counterparty_financial_account, "must belong to the current account")
    end

    if financial_liability.present? && financial_liability.account_id != account_id
      errors.add(:financial_liability, "must belong to the current account")
    end
  end
end
