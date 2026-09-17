class Financial::PlannedTransaction < PlannedExpense
  KINDS = %w[outflow liability_charge transfer liability_payment].freeze
  EXECUTION_STATUSES = %w[pending applied cancelled skipped].freeze
  IMPORTANCES = %w[low normal high essential].freeze

  belongs_to :income_event, optional: true
  belongs_to :plan, class_name: "Financial::Plan", foreign_key: :income_event_id, optional: true

  alias_attribute :planned_amount, :amount
  alias_attribute :planned_execution_date, :planned_for

  before_validation :append_to_plan, on: :create

  validates :kind, inclusion: { in: KINDS }
  validates :execution_status, inclusion: { in: EXECUTION_STATUSES }
  validates :importance, inclusion: { in: IMPORTANCES }
  validates :position, numericality: { only_integer: true, greater_than: 0 }, uniqueness: { scope: :income_event_id }, if: :income_event_id?
  validate :plan_accepts_expectation_changes

  scope :unassigned, -> { where(income_event_id: nil) }

  def pending_cash_requirement?
    execution_status == "pending" && kind.in?(%w[outflow liability_payment])
  end

  def actual_payment_date
    financial_entry&.entry_date
  end

  def payment_timing
    return if due_date.blank? || actual_payment_date.blank?
    return :early if actual_payment_date < due_date
    return :late if actual_payment_date > due_date

    :on_time
  end

  def route_description
    "#{route_source_label} → #{route_destination_label}"
  end

  def route_complete?
    !route_source_label.start_with?("Missing") && !route_destination_label.start_with?("Missing")
  end

  def route_source_label
    return financial_account.name if financial_account
    return financial_liability.name if kind == "liability_charge" && financial_liability

    "Missing source"
  end

  def route_destination_label
    case kind
    when "transfer"
      counterparty_financial_account&.name || "Missing destination"
    when "liability_payment"
      financial_liability&.name || "Missing destination"
    else
      "Expense"
    end
  end

  private

  def append_to_plan
    return if income_event_id.blank? || position.present?

    self.position = self.class.where(income_event_id: income_event_id).maximum(:position).to_i + 1
  end

  def plan_accepts_expectation_changes
    changed_expectation = new_record? || (changes.keys & %w[description amount kind planned_for due_date importance category_id financial_account_id counterparty_financial_account_id financial_liability_id income_event_id position commits_plan_funds]).any?
    return unless changed_expectation && plan&.lifecycle_status.in?(%w[closed cancelled])

    errors.add(:plan, "must be active before changing planned transactions")
  end
end
