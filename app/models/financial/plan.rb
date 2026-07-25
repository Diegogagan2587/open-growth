class Financial::Plan < ApplicationRecord
  self.table_name = "financial_plans"

  LIFECYCLE_STATUSES = %w[draft active closed cancelled].freeze

  has_many :funding_sources,
    class_name: "Financial::FundingSource",
    foreign_key: :financial_plan_id,
    inverse_of: :financial_plan,
    dependent: :destroy
  has_many :funding_entries, through: :funding_sources, source: :receipt_entry
  has_many :planned_transactions,
    class_name: "Financial::PlannedTransaction",
    foreign_key: :income_event_id,
    inverse_of: :plan,
    dependent: :destroy

  validates :lifecycle_status, inclusion: { in: LIFECYCLE_STATUSES }
  validate :closed_chronology_is_immutable, on: :update
  before_destroy :allow_safe_draft_deletion

  scope :chronological, -> { order(:expected_date, :id) }

  # Loan terms and routing belong to Financial::Loan. Treating a plan row as a
  # legacy IncomeEvent loan would re-run obsolete validations and callbacks.
  def loan?
    false
  end

  private

  def allow_safe_draft_deletion
    return if lifecycle_status == "draft" && financial_entries.none? && funding_sources.none?(&:receipt_entry)

    errors.add(:base, "only an empty draft plan can be deleted; cancel it instead")
    throw :abort
  end

  def closed_chronology_is_immutable
    return unless lifecycle_status.in?(%w[closed cancelled])
    return unless will_save_change_to_expected_date? || will_save_change_to_budget_period_id?

    errors.add(:base, "closed or cancelled plan chronology cannot be changed")
  end
end
