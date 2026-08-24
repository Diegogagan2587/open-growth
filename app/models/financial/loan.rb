class Financial::Loan < ApplicationRecord
  self.table_name = "financial_loans"

  LIFECYCLE_STATUSES = %w[simulated active paid cancelled].freeze

  belongs_to :account, class_name: "::Account"
  belongs_to :liability, class_name: "Financial::Liability", optional: true
  belongs_to :destination_asset, class_name: "Financial::Asset", optional: true
  belongs_to :destination_liability, class_name: "Financial::Liability", optional: true
  belongs_to :interest_category, class_name: "Category", optional: true
  has_many :funding_sources, class_name: "Financial::FundingSource", foreign_key: :financial_loan_id, dependent: :restrict_with_error
  has_many :entries, class_name: "Financial::Entry", foreign_key: :financial_loan_id, dependent: :restrict_with_error
  has_many :installments, class_name: "Financial::Loan::Installment", foreign_key: :financial_loan_id, inverse_of: :financial_loan, dependent: :restrict_with_error

  validates :name, presence: true
  validates :principal_amount, numericality: { greater_than: 0 }
  validates :interest_rate, numericality: { greater_than_or_equal_to: 0 }, allow_nil: true
  validates :repayment_basis, inclusion: { in: Financial::Loans::RepaymentTerms::BASES }, allow_nil: true
  validates :payment_amount, :different_payment_amount, numericality: { greater_than: 0 }, allow_nil: true
  validates :different_payment_position, inclusion: { in: %w[beginning final] }
  validates :lifecycle_status, inclusion: { in: LIFECYCLE_STATUSES }
  validate :repayment_terms_are_valid
  validate :active_routing_is_complete
  validate :associations_belong_to_same_account

  scope :for_account, ->(account) { where(account: account) }

  def actual_balance
    return 0.to_d unless liability

    entries.sum(0.to_d) { |entry| entry.liability_delta_for(liability_id) }
  end

  def configure_repayment(terms)
    self.repayment_basis = terms.repayment_basis
    self.number_of_payments = terms.number_of_payments
    self.payment_frequency = terms.payment_frequency
    self.interest_rate = terms.annual_rate
    self.payment_amount = terms.regular_payment
    self.different_payment_amount = terms.different_payment_amount
    self.different_payment_position = terms.different_payment_position
    self
  end

  def repayment_terms
    basis = repayment_basis.presence || (payment_amount.present? ? "payment_amounts" : (interest_rate.present? ? "annual_rate" : nil))
    Financial::Loans::RepaymentTerms.new(
      principal: principal_amount,
      number_of_payments: number_of_payments,
      payment_frequency: payment_frequency,
      repayment_basis: basis,
      annual_rate: interest_rate,
      regular_payment: payment_amount,
      different_payment_amount: different_payment_amount,
      different_payment_position: different_payment_position
    )
  end

  def interest_rate_estimated?
    repayment_basis == "payment_amounts"
  end

  def projected_repayment
    installments.sum(:expected_amount)
  end

  def projected_interest
    installments.sum(:expected_interest)
  end

  def remaining_projected_interest
    installments.where.not(resolution: "paid").sum(:expected_interest)
  end

  def regenerate_schedule!(start_date: nil, first_payment_date: nil, reset_manual_installment_ids: [])
    start_date = start_date&.to_date
    first_payment_date = first_payment_date&.to_date || self.first_payment_date
    reset_manual_installment_ids = Array(reset_manual_installment_ids).map(&:to_i)

    with_lock do
      terms = repayment_terms
      paid = installments.where(resolution: "paid").order(:installment_number).to_a
      ensure_removable_schedule_extras!(terms.number_of_payments)
      raise ArgumentError, "First payment date is required" if first_payment_date.blank? && start_date.blank?

      projections = Financial::Loans::AmortizationSchedule.build(
        terms: terms,
        start_date: start_date,
        first_payment_date: first_payment_date,
        paid_installments: paid
      )

      ActiveRecord::Base.transaction do
        update!(first_payment_date: first_payment_date) if first_payment_date.present?
        reconciled = projections.map { |projection| reconcile_schedule_installment!(projection, reset_manual_installment_ids) }
        installments.where("installment_number > ?", terms.number_of_payments).delete_all
        paid + reconciled
      end
    end
  end

  private

  def ensure_removable_schedule_extras!(number_of_payments)
    protected_extra = installments
      .where("installment_number > ?", number_of_payments)
      .where("planned_transaction_id IS NOT NULL OR payment_entry_id IS NOT NULL OR resolution = 'paid'")
      .exists?
    raise ArgumentError, "Payment count cannot remove a planned or paid installment" if protected_extra
  end

  def reconcile_schedule_installment!(projection, reset_manual_installment_ids)
    installment = installments.find_or_initialize_by(installment_number: projection.installment_number)
    raise ArgumentError, "Paid installments cannot be regenerated" if installment.resolution == "paid"

    installment.assign_attributes(
      account: account,
      due_date: schedule_due_date_for(installment, projection, reset_manual_installment_ids),
      manual_due_date: installment.manual_due_date && !reset_manual_installment_ids.include?(installment.id),
      expected_amount: projection.amount,
      expected_principal: projection.principal,
      expected_interest: projection.interest,
      resolution: "scheduled"
    )
    installment.save!
    installment
  end

  def schedule_due_date_for(installment, projection, reset_manual_installment_ids)
    return projection.due_date if installment.new_record? || reset_manual_installment_ids.include?(installment.id)
    return installment.due_date if installment.manual_due_date?

    projection.due_date
  end

  def repayment_terms_are_valid
    return if repayment_basis.blank?

    repayment_terms
  rescue ArgumentError => error
    errors.add(:base, error.message)
  end

  def active_routing_is_complete
    return unless lifecycle_status == "active"

    errors.add(:liability, "must be selected") if liability.blank?
    destinations = [ destination_asset, destination_liability ].compact
    errors.add(:base, "active loan requires exactly one destination") unless destinations.one?
  end

  def associations_belong_to_same_account
    [ :liability, :destination_asset, :destination_liability, :interest_category ].each do |association|
      record = public_send(association)
      errors.add(association, "must belong to the current account") if record && record.account_id != account_id
    end
  end
end
