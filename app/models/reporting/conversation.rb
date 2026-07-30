# frozen_string_literal: true

class Reporting::Conversation < ApplicationRecord
  self.table_name = "reporting_conversations"

  belongs_to :account
  belongs_to :account_membership
  has_many :turns, class_name: "Reporting::Turn", dependent: :destroy
  has_many :usage_events, class_name: "Reporting::UsageEvent", dependent: :nullify

  validates :title, :date_from, :date_to, presence: true
  validate :membership_belongs_to_account
  validate :valid_date_range

  before_update :prevent_scope_changes

  scope :recent_first, -> { order(updated_at: :desc) }

  private

  def membership_belongs_to_account
    return if account.blank? || account_membership.blank?
    return if account_membership.account_id == account_id

    errors.add(:account_membership, "must belong to the conversation account")
  end

  def valid_date_range
    return if date_from.blank? || date_to.blank?

    errors.add(:date_to, "must be on or after the start date") if date_to < date_from
    errors.add(:date_to, "cannot make the range longer than 366 days") if (date_to - date_from).to_i > 365
  end

  def prevent_scope_changes
    return unless account_id_changed? || account_membership_id_changed? || date_from_changed? || date_to_changed?

    errors.add(:base, "conversation scope cannot be changed")
    throw :abort
  end
end
