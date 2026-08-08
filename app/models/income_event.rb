class IncomeEvent < ApplicationRecord
  attr_accessor :destination_selection

  belongs_to :account
  belongs_to :budget_period, optional: true
  belongs_to :loan_liability, class_name: "Financial::Liability", optional: true
  belongs_to :loan_disbursement_destination_asset, class_name: "Financial::Asset", optional: true
  belongs_to :loan_disbursement_destination_liability, class_name: "Financial::Liability", optional: true
  belongs_to :regular_income_destination_asset, class_name: "Financial::Asset", optional: true
  belongs_to :regular_income_destination_liability, class_name: "Financial::Liability", optional: true
  has_many :planned_expenses, dependent: :destroy
  has_many :originated_planned_expenses, class_name: "PlannedExpense", foreign_key: :origin_income_event_id, dependent: :nullify
  has_many :expenses, dependent: :nullify
  has_many :financial_entries, class_name: "Financial::Entry", dependent: :nullify
  has_many :funding_sources, class_name: "Financial::FundingSource", foreign_key: :financial_plan_id, dependent: :restrict_with_error
  has_many :loan_payment_schedules, foreign_key: :loan_id, dependent: :destroy
  has_one :loan_disbursement_entry, -> { where(entry_type: "loan_disbursement") }, class_name: "Financial::Entry", inverse_of: :income_event
  has_one :regular_income_entry, -> { where(entry_type: "inflow", expense_id: nil, planned_expense_id: nil) }, class_name: "Financial::Entry", inverse_of: :income_event

  before_validation :set_account, on: :create
  before_validation :normalize_payment_frequency
  before_validation :apply_loan_defaults
  before_validation :assign_destination_selection
  before_validation :infer_loan_interest_rate
  after_commit :sync_loan_side_effects, if: :loan?

  scope :for_account, ->(account) { where(account: account) }
  scope :regular, -> { where(income_type: "regular") }
  scope :loans, -> { where(income_type: "loan") }

  validates :expected_date, presence: true
  validates :expected_amount, presence: true, numericality: { greater_than: 0 }
  validates :description, presence: true
  validates :status, presence: true, inclusion: { in: %w[pending received applied] }
  validates :income_type, presence: true, inclusion: { in: %w[regular loan] }
  validates :loan_amount, presence: true, numericality: { greater_than: 0 }, if: :loan?
  validates :number_of_payments, presence: true, numericality: { greater_than: 0, only_integer: true }, if: :loan?
  validates :payment_frequency, presence: true, inclusion: { in: %w[weekly biweekly quincenal monthly] }, if: :loan?
  validates :interest_rate, numericality: { greater_than_or_equal_to: 0 }, allow_nil: true
  validates :payment_amount, numericality: { greater_than: 0 }, allow_nil: true
  validate :loan_terms_present_for_calculation, if: :loan?
  validate :loan_payment_amount_consistency, if: :loan?
  validate :loan_routing_presence, if: :loan?
  validate :loan_routing_account_ownership, if: :loan?
  validate :regular_income_destination_presence, if: :regular_income_destination_set?
  validate :regular_income_destination_account_ownership, unless: :loan?
  validate :budget_period_account_ownership

  scope :pending, -> { where(status: "pending") }
  scope :received, -> { where(status: "received") }
  scope :applied, -> { where(status: "applied") }
  scope :by_date, -> { order(expected_date: :desc) }

  private def sync_compatibility_plan
    attributes = {
      id: id,
      account_id: account_id,
      budget_period_id: budget_period_id,
      name: description,
      planned_for: expected_date,
      lifecycle_status: lifecycle_status.presence || "active",
      closed_at: closed_at,
      actual_ending_balance_at_close: actual_ending_balance_at_close,
      legacy_income_event_id: id,
      created_at: created_at,
      updated_at: updated_at
    }
    Financial::Plan.upsert(attributes, unique_by: :id)
    Financial::FundingSource.upsert({
      account_id: account_id,
      financial_plan_id: id,
      description: description,
      expected_amount: expected_amount,
      expected_date: expected_date,
      kind: loan? ? "borrowed" : "income",
      resolution: status.in?(%w[received applied]) ? "received" : "pending",
      expected_destination_account_id: legacy_destination_account&.id,
      legacy_income_event_id: id,
      created_at: created_at,
      updated_at: updated_at
    }, unique_by: :index_financial_funding_sources_on_legacy_income_event_id)
    source = Financial::FundingSource.find_by(legacy_income_event_id: id)
    source&.resolve_from!(source.receipt_transaction) if source&.receipt_transaction
  end

  private def legacy_destination_account
    if loan?
      loan_disbursement_destination_asset || loan_disbursement_destination_liability
    else
      regular_income_destination_asset || regular_income_destination_liability
    end
  end

  private def sync_regular_income_transaction
    IncomeEvents::TransactionSyncService.call(self)
  end

  def total_planned
    return loan_total_planned if loan?

    # Include:
    # 1. All planned expenses (they represent planned spending, even if applied)
    # 2. Expenses directly assigned (without a planned_expense_id)
    # Note: Expenses created from planned expenses (with planned_expense_id) are NOT counted
    # to avoid double-counting, as they're already represented by the planned expense
    planned_expenses.budget_consuming.sum(:amount) + financial_entries.where(planned_expense_id: nil, entry_type: %w[outflow liability_charge]).sum(:amount)
  end

  def total_spent
    return loan_total_spent if loan?

    # Total of all expenses (both from planned and direct)
    financial_entries.where(entry_type: %w[outflow liability_charge]).sum(:amount)
  end

  def remaining_budget
    income_amount = received_amount || expected_amount
    income_amount - total_planned
  end

  def planned_expenses_ordered
    planned_expenses.order(:position, :created_at)
  end

  def receive!(date, amount)
    update!(
      received_date: date,
      received_amount: amount,
      status: "received"
    )
  end

  def ensure_primary_funding_source!
    source = funding_sources.find_or_initialize_by(legacy_income_event_id: id)
    source.assign_attributes(
      account: account,
      description: description,
      expected_amount: expected_amount,
      expected_date: expected_date,
      kind: loan? ? "borrowed" : "income",
      expected_destination_account: legacy_destination_account
    )
    source.save!

    entry = loan? ? loan_disbursement_entry : regular_income_entry
    entry&.update!(funding_source: source) if entry&.funding_source_id.blank?
    source
  end

  def apply_all!
    if loan?
      Loans::ApplyService.call(self)
      return
    end

    planned_expenses.where.not(status: %w[paid transferred spent]).find_each do |planned_expense|
      planned_expense.apply!
    end
    update!(status: "applied")
  end

  def is_received?
    received_date.present?
  end

  def is_applied?
    status == "applied"
  end

  def previous_income_event
    return nil unless budget_period_id

    # Get the date to use for ordering: received_date if present, otherwise expected_date
    current_date = received_date || expected_date
    current_id = id

    # Find previous event: the one with the highest effective date that is still before current
    # Effective date = received_date if present, otherwise expected_date
    # Load all events and calculate in Ruby for clarity and correctness
    candidates = budget_period.income_events.where.not(id: current_id).to_a

    # Calculate effective date for current event
    current_effective_date = current_date

    # Find all events that come before current (by effective date)
    previous_events = candidates.select do |event|
      event_effective_date = event.received_date || event.expected_date
      event_effective_date < current_effective_date ||
        (event_effective_date == current_effective_date && event.id < current_id)
    end

    return nil if previous_events.empty?

    # Return the one with the highest effective date (most recent before current)
    previous_events.max_by do |event|
      event_effective_date = event.received_date || event.expected_date
      [ event_effective_date, event.id ]
    end
  end

  def previous_balance
    prev = previous_income_event
    return 0.0 unless prev

    # Use effective_remaining_budget to account for cumulative carryover
    # This ensures that if the previous event itself had a previous balance,
    # we carry forward the complete effective balance
    prev.effective_remaining_budget
  end

  def effective_remaining_budget
    # If previous_balance is negative (deficit), it reduces available budget
    # If previous_balance is positive (surplus), it increases available budget
    remaining_budget + previous_balance
  end

  def loan?
    income_type == "loan"
  end

  def regular?
    !loan?
  end

  def loan_payment_schedules_ordered
    loan_payment_schedules.ordered
  end

  def loan_total_repayment
    loan_payment_schedules.active.sum(:amount)
  end

  def loan_total_paid
    loan_payment_schedules.paid.sum(:amount)
  end

  def loan_remaining_balance
    loan_amount.to_d - loan_total_paid.to_d
  end

  def generate_loan_payment_schedules!(preserve_paid: true)
    if Rails.env.development?
      ::Loans.send(:remove_const, :ScheduleGenerator) if defined?(::Loans::ScheduleGenerator)
      load Rails.root.join("app/services/loans/schedule_generator.rb")
    elsif !defined?(::Loans::ScheduleGenerator)
      require Rails.root.join("app/services/loans/schedule_generator")
    end

    ::Loans::ScheduleGenerator.call(self, preserve_paid: preserve_paid)
  end

  def inferred_interest_rate?
    interest_rate_estimated
  end

  def destination_selection
    @destination_selection || selection_for_destination
  end

  def destination_selection=(value)
    @destination_selection = value.presence
  end

  private

  def set_account
    self.account ||= Current.account if Current.account
  end

  def normalize_payment_frequency
    return if payment_frequency.blank?

    self.payment_frequency = "quincenal" if payment_frequency == "quicenal"
  end

  def apply_loan_defaults
    self.income_type ||= "regular"
    return unless loan?

    self.loan_amount ||= expected_amount
    self.expected_amount = loan_amount if loan_amount.present?
    self.expected_date ||= Date.current
    self.received_amount ||= loan_amount if received_amount.blank?
  end

  def infer_loan_interest_rate
    return unless loan?
    if interest_rate.present?
      self.interest_rate_estimated = false if will_save_change_to_interest_rate?
      return
    end
    return unless payment_amount.present? && number_of_payments.present? && loan_amount.present?

    self.interest_rate = inferred_annual_rate_from_payment
    self.interest_rate_estimated = true
  end

  def loan_total_planned
    loan_payment_schedules.active.sum(:amount)
  end

  def loan_total_spent
    loan_payment_schedules.paid.sum(:amount)
  end

  def sync_loan_side_effects
    generate_loan_payment_schedules!
    Loans::PlannedExpenseSyncService.call(self)
    Loans::DisbursementSyncService.call(self) if status == "applied"
  end

  def loan_terms_present_for_calculation
    return if interest_rate.present? || payment_amount.present?

    errors.add(:base, "Provide interest rate or payment amount to build the loan schedule")
  end

  def loan_payment_amount_consistency
    return unless payment_amount.present? && number_of_payments.present? && loan_amount.present?
    return unless payment_amount.to_d * number_of_payments.to_i < loan_amount.to_d

    errors.add(:payment_amount, "is too low for the selected number of payments")
  end

  def assign_destination_selection
    return if @destination_selection.blank?

    kind, id = @destination_selection.split(":", 2)
    if loan?
      case kind
      when "asset"
        self.loan_disbursement_destination_asset_id = id
        self.loan_disbursement_destination_liability_id = nil
      when "liability"
        self.loan_disbursement_destination_liability_id = id
        self.loan_disbursement_destination_asset_id = nil
      end
    else
      case kind
      when "asset"
        self.regular_income_destination_asset_id = id
        self.regular_income_destination_liability_id = nil
      when "liability"
        self.regular_income_destination_liability_id = id
        self.regular_income_destination_asset_id = nil
      end
    end
  end

  def selection_for_destination
    if loan? && loan_disbursement_destination_asset_id.present?
      "asset:#{loan_disbursement_destination_asset_id}"
    elsif loan? && loan_disbursement_destination_liability_id.present?
      "liability:#{loan_disbursement_destination_liability_id}"
    elsif regular_income_destination_asset_id.present?
      "asset:#{regular_income_destination_asset_id}"
    elsif regular_income_destination_liability_id.present?
      "liability:#{regular_income_destination_liability_id}"
    end
  end

  def loan_routing_presence
    errors.add(:loan_liability, "must be selected") if loan_liability.blank?

    destinations = [ loan_disbursement_destination_asset_id, loan_disbursement_destination_liability_id ].compact
    return if destinations.size == 1

    errors.add(:destination_selection, "must select exactly one destination account")
  end

  def loan_routing_account_ownership
    return if account.blank?

    if loan_liability.present? && loan_liability.account_id != account_id
      errors.add(:loan_liability, "must belong to the current account")
    end

    if loan_disbursement_destination_asset.present? && loan_disbursement_destination_asset.account_id != account_id
      errors.add(:loan_disbursement_destination_asset, "must belong to the current account")
    end

    if loan_disbursement_destination_liability.present? && loan_disbursement_destination_liability.account_id != account_id
      errors.add(:loan_disbursement_destination_liability, "must belong to the current account")
    end
  end

  def regular_income_destination_presence
    destinations = [ regular_income_destination_asset_id, regular_income_destination_liability_id ].compact
    return if destinations.size == 1

    errors.add(:destination_selection, "must select exactly one destination account")
  end

  def regular_income_destination_set?
    !loan? && (regular_income_destination_asset_id.present? || regular_income_destination_liability_id.present?)
  end

  def regular_income_destination_account_ownership
    return if account.blank?

    if regular_income_destination_asset.present? && regular_income_destination_asset.account_id != account_id
      errors.add(:regular_income_destination_asset, "must belong to the current account")
    end

    if regular_income_destination_liability.present? && regular_income_destination_liability.account_id != account_id
      errors.add(:regular_income_destination_liability, "must belong to the current account")
    end
  end

  def budget_period_account_ownership
    return if account.blank? || budget_period.blank? || budget_period.account_id == account_id

    errors.add(:budget_period, "must belong to the current account")
  end

  def inferred_annual_rate_from_payment
    Financial::Loans::RepaymentTerms.new(
      principal: loan_amount,
      number_of_payments: number_of_payments,
      payment_frequency: payment_frequency,
      repayment_basis: "payment_amounts",
      regular_payment: payment_amount
    ).annual_rate
  end
end
