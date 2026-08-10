class Financial::FundingSource < ApplicationRecord
  self.table_name = "financial_funding_sources"

  KINDS = %w[income borrowed refund gift sale deposit other].freeze
  RESOLUTIONS = %w[pending received not_received cancelled closed_with_variance].freeze

  belongs_to :account, class_name: "::Account"
  belongs_to :financial_plan, class_name: "Financial::Plan", inverse_of: :funding_sources
  belongs_to :financial_loan, class_name: "Financial::Loan", optional: true, inverse_of: :funding_sources
  belongs_to :expected_destination_account, class_name: "Financial::Account", optional: true
  has_one :receipt_transaction,
    class_name: "Financial::Transaction",
    foreign_key: :funding_source_id,
    inverse_of: :funding_source,
    dependent: :restrict_with_error

  before_validation :set_owner_account, on: :create

  validates :description, :expected_date, presence: true
  validates :expected_amount, numericality: { greater_than: 0 }
  validates :kind, inclusion: { in: KINDS }
  validates :resolution, inclusion: { in: RESOLUTIONS }
  validate :associations_belong_to_same_account
  validate :single_expected_destination
  validate :plan_accepts_expectation_changes

  alias_method :receipt_entry, :receipt_transaction

  def actual_amount
    receipt_transaction&.amount
  end

  def actual_date
    receipt_transaction&.transaction_date
  end

  private

  def set_owner_account
    self.account ||= financial_plan&.account || Current.account
  end

  def associations_belong_to_same_account
    %i[financial_plan financial_loan expected_destination_account].each do |association|
      record = public_send(association)
      next unless record.respond_to?(:account_id) && record.account_id != account_id

      errors.add(association, "must belong to the current account")
      errors.add(:expected_destination_asset, "must belong to the current account") if association == :expected_destination_account && record.asset?
      errors.add(:expected_destination_liability, "must belong to the current account") if association == :expected_destination_account && record.liability?
    end
  end

  def single_expected_destination
    return unless expected_destination_asset.present? && expected_destination_liability.present?

    errors.add(:base, "select only one expected destination")
  end

  def plan_accepts_expectation_changes
    changed_expectation = new_record? || (changes.keys & %w[description expected_amount expected_date kind expected_destination_asset_id expected_destination_liability_id]).any?
    return unless changed_expectation && financial_plan&.lifecycle_status.in?(%w[closed cancelled])

    errors.add(:financial_plan, "must be active before changing funding expectations")
  end
end
