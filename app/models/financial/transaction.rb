class Financial::Transaction < ApplicationRecord
  self.table_name = "financial_transactions"

  BANK_VISIBLE_FIELDS = %w[amount transaction_date transaction_type source_account_id destination_account_id].freeze

  def self.transaction_types
    Financial::Transactions::AccountRoute.transaction_types
  end

  belongs_to :account, class_name: "::Account"
  belongs_to :category, optional: true
  belongs_to :budget_period, optional: true
  belongs_to :source_account, class_name: "Financial::Account", optional: true, inverse_of: :outgoing_transactions
  belongs_to :destination_account, class_name: "Financial::Account", optional: true, inverse_of: :incoming_transactions
  belongs_to :plan, class_name: "Financial::Plan", optional: true, inverse_of: :transactions
  belongs_to :planned_transaction, class_name: "Financial::PlannedTransaction", optional: true, inverse_of: :actual_transaction
  belongs_to :funding_source, class_name: "Financial::FundingSource", optional: true, inverse_of: :receipt_transaction
  belongs_to :financial_loan, class_name: "Financial::Loan", optional: true, inverse_of: :transactions
  belongs_to :expense, optional: true

  # Compatibility associations retained through the production audit window.
  belongs_to :financial_account, class_name: "Financial::Account", optional: true
  belongs_to :counterparty_financial_account, class_name: "Financial::Account", optional: true
  belongs_to :financial_liability, class_name: "Financial::Account", optional: true
  belongs_to :counterparty_financial_liability, class_name: "Financial::Account", optional: true
  belongs_to :income_event, optional: true
  belongs_to :planned_expense, optional: true

  before_validation :set_owner_account, on: :create
  before_validation :infer_transaction_type_from_account_route
  before_validation :synchronize_compatibility_routing

  scope :for_account, ->(account) { where(account: account) }
  scope :by_date, -> { order(transaction_date: :desc, entry_time: :desc, created_at: :desc) }
  scope :reconciled, -> { where.not(reconciled_at: nil) }
  scope :unreconciled, -> { where(reconciled_at: nil) }
  scope :funding, -> { where(transaction_type: Financial::Transactions::AccountRoute.funding_transaction_types) }
  scope :expenses, -> { where(transaction_type: "expense") }

  validates :transaction_type, inclusion: { in: ->(_) { Financial::Transaction.transaction_types } }
  validates :transaction_date, presence: true
  validates :amount, numericality: { greater_than: 0 }
  validates :description, presence: true
  validates :category, presence: true, if: :classification_required?
  validates :planned_transaction_id, uniqueness: true, allow_nil: true
  validates :planned_expense_id, uniqueness: true, allow_nil: true
  validates :funding_source_id, uniqueness: true, allow_nil: true
  validate :required_route
  validate :associations_belong_to_same_account
  validate :plan_is_open_for_new_actuals, on: :create

  def correct!(attributes)
    self.class.transaction do
      assign_attributes(attributes)
      self.reconciled_at = nil if reconciled_at? && (changes.keys & BANK_VISIBLE_FIELDS).any?
      save!
      synchronize_origin!
    end
    self
  end

  def reconcile!
    update!(reconciled_at: Time.current) unless reconciled_at?
    self
  end

  def unreconcile!
    update!(reconciled_at: nil) if reconciled_at?
    self
  end

  def remove!
    self.class.transaction do
      ensure_disbursement_can_be_removed!
      planned_transaction&.update!(execution_status: "pending")
      funding_source&.update!(resolution: "pending")
      if (installment = Financial::LoanInstallment.find_by(payment_transaction_id: id))
        installment.update!(payment_transaction: nil, resolution: "scheduled")
      end
      financial_loan&.update!(lifecycle_status: "simulated") if transaction_type == "loan_disbursement"
      legacy_expense = expense
      legacy_expense&.destroy!
      destroy! unless destroyed?
    end
  end

  def account_delta_for(financial_account_id)
    synchronize_compatibility_routing if source_account_id.blank? && destination_account_id.blank?
    selected_account = Financial::Account.find_by(id: financial_account_id)
    return 0.to_d unless selected_account

    if selected_account.asset?
      return -amount.to_d if source_account_id == financial_account_id
      return amount.to_d if destination_account_id == financial_account_id
    else
      return amount.to_d if source_account_id == financial_account_id
      return -amount.to_d if destination_account_id == financial_account_id
    end
    0.to_d
  end

  def net_asset_effect
    [ source_account, destination_account ].compact.uniq.select(&:asset?).sum(0.to_d) { |record| account_delta_for(record.id) }
  end

  def net_liability_effect
    [ source_account, destination_account ].compact.uniq.select(&:liability?).sum(0.to_d) { |record| account_delta_for(record.id) }
  end

  def income?
    transaction_type.in?(%w[income refund])
  end

  alias_method :inflow?, :income?

  def funding?
    transaction_type.in?(Financial::Transactions::AccountRoute.funding_transaction_types)
  end

  def expense?
    transaction_type == "expense"
  end

  def classification_required?
    transaction_type == "expense"
  end

  def source_selection
    source_account_id
  end

  def entry_type
    return "inflow" if transaction_type == "income"
    return "outflow" if transaction_type == "expense" && source_account&.asset?
    return "liability_charge" if transaction_type == "expense"
    return "liability_payment" if transaction_type == "debt_payment"

    transaction_type
  end

  def entry_date
    transaction_date
  end

  def entry_date=(value)
    self.transaction_date = value
  end

  alias_method :date, :entry_date
  alias_method :date=, :entry_date=

  def destination_selection
    destination_account_id
  end

  def routed_source_account
    source_account || case entry_type
                      when "outflow", "transfer", "liability_payment", "adjustment" then financial_account
                      when "liability_charge", "loan_disbursement" then financial_liability
                      end
  end

  def routed_destination_account
    destination_account || case entry_type
                           when "inflow" then financial_account || counterparty_financial_liability
                           when "transfer" then counterparty_financial_account
                           when "liability_payment" then financial_liability
                           when "loan_disbursement" then financial_account || counterparty_financial_liability
                           end
  end

  private

  def set_owner_account
    self.account ||= Current.account if Current.account
  end

  def required_route
    account_route.validation_errors.each do |attribute, messages|
      messages.each { |message| errors.add(attribute, message) }
    end
  end

  def infer_transaction_type_from_account_route
    return unless transaction_type.blank? || route_semantics_changed?

    requested_type = transaction_type.presence || planned_route&.transaction_type
    inferred_type = Financial::Transactions::AccountRoute.for_actual(
      source: source_account,
      destination: destination_account,
      transaction_type: requested_type
    ).transaction_type
    self.transaction_type = inferred_type || requested_type
  end

  def route_semantics_changed?
    new_record? || will_save_change_to_transaction_type? || will_save_change_to_source_account_id? || will_save_change_to_destination_account_id?
  end

  def account_route
    Financial::Transactions::AccountRoute.for_actual(source: source_account, destination: destination_account, transaction_type: transaction_type)
  end

  def planned_route
    return unless planned_transaction

    Financial::Transactions::AccountRoute.for_planning(
      source: source_account,
      destination: destination_account,
      kind: planned_transaction.kind
    )
  end

  def associations_belong_to_same_account
    return if account.blank?

    %i[source_account destination_account category budget_period plan planned_transaction funding_source financial_loan].each do |association|
      record = public_send(association)
      errors.add(association, "must belong to the current account") if record.respond_to?(:account_id) && record.account_id != account_id
    end
  end

  def plan_is_open_for_new_actuals
    errors.add(:plan, "must be active before adding an actual transaction") if plan&.lifecycle_status.in?(%w[closed cancelled])
  end

  def synchronize_origin!
    funding_source&.resolve_from!(self)
    if planned_transaction
      planned_transaction.update!(execution_status: "applied")
      Financial::LoanInstallment.find_by(planned_transaction: planned_transaction)&.update!(payment_transaction: self, resolution: "paid")
    end
    financial_loan&.update!(lifecycle_status: "active") if transaction_type == "loan_disbursement"
  end

  def ensure_disbursement_can_be_removed!
    return unless transaction_type == "loan_disbursement" && financial_loan
    return unless financial_loan.transactions.where.not(id: id).exists? || financial_loan.installments.where(resolution: "paid").exists?

    errors.add(:base, "loan disbursement cannot be removed after repayments exist")
    raise ActiveRecord::RecordInvalid, self
  end

  def synchronize_compatibility_routing
    self.plan_id ||= income_event_id if income_event_id && Financial::Plan.exists?(income_event_id)
    self.planned_transaction_id ||= planned_expense_id if planned_expense_id && Financial::PlannedTransaction.exists?(planned_expense_id)
    self.income_event_id ||= plan_id if plan_id && IncomeEvent.exists?(plan_id)
    self.planned_expense_id ||= planned_transaction_id if planned_transaction_id && PlannedExpense.exists?(planned_transaction_id)

    if source_account_id.blank? && destination_account_id.blank?
      infer_canonical_route_from_legacy_columns
    else
      populate_legacy_columns_from_canonical_route
    end
  end

  def infer_canonical_route_from_legacy_columns
    case transaction_type
    when "income", "refund"
      self.destination_account_id = financial_account_id || counterparty_financial_liability_id
    when "expense"
      self.source_account_id = financial_account_id || financial_liability_id
    when "transfer"
      self.source_account_id = financial_account_id
      self.destination_account_id = counterparty_financial_account_id
    when "debt_payment"
      self.source_account_id = financial_account_id
      self.destination_account_id = financial_liability_id
    when "loan_disbursement"
      self.source_account_id = financial_liability_id
      self.destination_account_id = financial_account_id || counterparty_financial_liability_id
    when "adjustment"
      self.destination_account_id = financial_account_id
    end
  end

  def populate_legacy_columns_from_canonical_route
    self.financial_account_id = nil
    self.counterparty_financial_account_id = nil
    self.financial_liability_id = nil
    self.counterparty_financial_liability_id = nil

    case transaction_type
    when "income", "refund"
      destination_account&.asset? ? self.financial_account_id = destination_account_id : self.counterparty_financial_liability_id = destination_account_id
    when "expense"
      source_account&.asset? ? self.financial_account_id = source_account_id : self.financial_liability_id = source_account_id
    when "transfer"
      self.financial_account_id = source_account_id
      self.counterparty_financial_account_id = destination_account_id
    when "debt_payment"
      self.financial_account_id = source_account_id
      self.financial_liability_id = destination_account_id
    when "loan_disbursement"
      self.financial_liability_id = source_account_id
      destination_account&.asset? ? self.financial_account_id = destination_account_id : self.counterparty_financial_liability_id = destination_account_id
    when "adjustment"
      self.financial_account_id = destination_account_id
    end
  end
end
