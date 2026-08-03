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
  has_many :installments, class_name: "Financial::LoanInstallment", foreign_key: :financial_loan_id, inverse_of: :financial_loan, dependent: :restrict_with_error

  validates :name, presence: true
  validates :principal_amount, numericality: { greater_than: 0 }
  validates :interest_rate, numericality: { greater_than_or_equal_to: 0 }, allow_nil: true
  validates :repayment_basis, inclusion: { in: Financial::Loans::RepaymentTerms::BASES }, allow_nil: true
  validates :payment_amount, :final_payment_amount, numericality: { greater_than: 0 }, allow_nil: true
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
    self.final_payment_amount = terms.final_payment
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
      final_payment: final_payment_amount
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

  private

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
