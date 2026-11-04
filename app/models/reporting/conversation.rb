# frozen_string_literal: true

class Reporting::Conversation < ApplicationRecord
  self.table_name = "reporting_conversations"

  belongs_to :account
  belongs_to :account_membership
  has_many :turns, class_name: "Reporting::Turn", dependent: :destroy
  has_many :usage_events, class_name: "Reporting::UsageEvent", dependent: :nullify

  validates :title, presence: true
  validate :membership_belongs_to_account

  scope :recent_first, -> { order(updated_at: :desc) }

  private

  def membership_belongs_to_account
    return if account.blank? || account_membership.blank?
    return if account_membership.account_id == account_id

    errors.add(:account_membership, "must belong to the conversation account")
  end

end
