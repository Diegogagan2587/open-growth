# frozen_string_literal: true

class Reporting::Turn < ApplicationRecord
  self.table_name = "reporting_turns"

  STATUSES = %w[queued processing completed failed canceled].freeze

  belongs_to :conversation, class_name: "Reporting::Conversation", touch: true
  has_one :usage_event, class_name: "Reporting::UsageEvent", dependent: :nullify

  validates :question, presence: true, length: { maximum: 4_000 }
  validates :status, inclusion: { in: STATUSES }

  scope :completed, -> { where(status: "completed") }
  scope :stale, ->(before:) { where(status: %w[queued processing]).where("created_at < ?", before) }

  after_update_commit :broadcast_update

  private

  def broadcast_update
    broadcast_replace_to conversation, target: ActionView::RecordIdentifier.dom_id(self),
      partial: "reports/analysis_turns/turn", locals: { turn: self }
  end
end
