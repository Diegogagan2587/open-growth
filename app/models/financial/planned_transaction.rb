class Financial::PlannedTransaction < PlannedExpense
  KINDS = %w[outflow liability_charge transfer liability_payment].freeze
  EXECUTION_STATUSES = %w[pending applied cancelled skipped].freeze
  IMPORTANCES = %w[low normal high essential].freeze
  
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

  def status
    {
      "pending" => "pending_to_pay",
      "applied" => kind == "transfer" ? "transferred" : "paid"
    }.fetch(execution_status, execution_status)
  end

  def status=(value)
    self.execution_status = case value.to_s
    when "pending_to_pay" then "pending"
    when "paid", "spent", "transferred" then "applied"
    else value
    end
  end

  def income_event_id
    plan_id
  end

  def income_event_id=(value)
    self.plan_id = value
  end

  def income_event
    plan
  end

  def source_selection
    source_account_id
  end

  def source_selection=(value)
    self.source_account_id = account_id_from_selection(value)
  end

  def destination_selection
    destination_account_id
  end

  def destination_selection=(value)
    self.destination_account_id = account_id_from_selection(value)
  end

  def financial_account
    source_account if source_account&.asset?
  end

  def financial_account=(value)
    self.source_account = value
  end

  def counterparty_financial_account
    destination_account if destination_account&.asset?
  end

  def counterparty_financial_account=(value)
    self.destination_account = value
  end

  def financial_liability
    source_account&.liability? ? source_account : destination_account&.liability? ? destination_account : nil
  end

  def financial_liability=(value)
    kind == "liability_payment" ? self.destination_account = value : self.source_account = value
  end

  def budget_consuming?
    self[:budget_consuming]
  end

  def transfer?
    kind == "transfer"
  end

  def debt_payment?
    kind == "liability_payment"
  end

  def routing_summary
    return "Transfer from #{source_account.name} to #{destination_account.name}" if transfer?
    return "Pay #{destination_account.name} from #{source_account.name}" if debt_payment?
    return "Charged to #{source_account.name}" if kind == "liability_charge" && source_account
    return "Pay from #{source_account.name}" if source_account
  end

  def classification_label
    category&.name || (debt_payment? ? "Card payment" : transfer? ? "Transfer" : "Uncategorized")
  end

  private

  def append_to_plan
    return if income_event_id.blank? || position.present?

    self.position = self.class.where(income_event_id: income_event_id).maximum(:position).to_i + 1
  end

  def set_owner_account
    self.account ||= plan&.account || Current.account
  end

  def account_id_from_selection(value)
    value.to_s.split(":", 2).last.presence
  end

  def infer_kind
    self.kind ||= if destination_account&.liability?
      "liability_payment"
    elsif source_account&.liability?
      "liability_charge"
    elsif destination_account
      "transfer"
    else
      "outflow"
    end
  end

  def set_budget_consuming_default
    self.budget_consuming = kind.in?(%w[outflow liability_charge]) if budget_consuming.nil?
  end

  def append_to_plan
    return if plan_id.blank? || position.present?

    self.position = self.class.where(plan_id: plan_id).maximum(:position).to_i + 1
  end

  def route_is_valid
    errors.add(:destination_account, "must differ from source account") if source_account_id.present? && source_account_id == destination_account_id
    errors.add(:destination_account, "must be selected") if kind.in?(%w[transfer liability_payment]) && destination_account.blank?
  end

  def associations_belong_to_same_account
    return if account.blank?

    %i[plan category savings_goal recurring_transaction shopping_item source_account destination_account].each do |association|
      record = public_send(association)
      errors.add(association, "must belong to the current account") if record.respond_to?(:account_id) && record.account_id != account_id
    end
  end

  def plan_accepts_expectation_changes
    changed_expectation = new_record? || (changes.keys & %w[description amount kind planned_for due_date importance category_id financial_account_id counterparty_financial_account_id financial_liability_id income_event_id position commits_plan_funds]).any?
    return unless changed_expectation && plan&.lifecycle_status.in?(%w[closed cancelled])

    errors.add(:plan, "must be active before changing planned transactions")
  end
end
