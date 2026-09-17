class Financial::Plan < IncomeEvent
  LIFECYCLE_STATUSES = %w[draft active closed cancelled].freeze

  alias_attribute :name, :description
  alias_attribute :planned_for, :expected_date

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

  def default_transaction_order
    custom_ordered? ? :custom : :due_date
  end

  def reorder_planned_transactions!(ordered_ids)
    ids = Array(ordered_ids).map(&:to_i)

    with_lock do
      current_ids = planned_transactions.order(:id).ids
      unless ids.length == ids.uniq.length && ids.sort == current_ids.sort
        errors.add(:planned_transactions, "must include every plan movement exactly once")
        raise ActiveRecord::RecordInvalid, self
      end
      if lifecycle_status.in?(%w[closed cancelled])
        errors.add(:planned_transactions, "cannot be reordered after the plan is finalized")
        raise ActiveRecord::RecordInvalid, self
      end

      planned_transactions.order(:position, :id).each_with_index do |transaction, index|
        transaction.update_columns(position: -(index + 1))
      end
      planned_transactions.index_by(&:id).then do |transactions_by_id|
        ids.each_with_index do |id, index|
          transactions_by_id.fetch(id).update_columns(position: index + 1)
        end
      end
      update!(custom_ordered: true)
    end
  end

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
