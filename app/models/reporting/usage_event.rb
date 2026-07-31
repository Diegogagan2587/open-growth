# frozen_string_literal: true

class Reporting::UsageEvent < ApplicationRecord
  self.table_name = "reporting_usage_events"

  COUNTED_STATUSES = %w[reserved processing completed provider_failed].freeze

  belongs_to :account
  belongs_to :user
  belongs_to :account_membership, optional: true
  belongs_to :conversation, class_name: "Reporting::Conversation", optional: true
  belongs_to :turn, class_name: "Reporting::Turn", optional: true

  validates :status, inclusion: { in: COUNTED_STATUSES + %w[canceled] }
  validates :model, presence: true
  validate :membership_belongs_to_account

  scope :counted, -> { where(status: COUNTED_STATUSES) }
  scope :during, ->(range) { where(created_at: range) }

  private

  def membership_belongs_to_account
    return if account.blank? || account_membership.blank?
    return if account_membership.account_id == account_id

    errors.add(:account_membership, "must belong to the usage account")
  end
end
