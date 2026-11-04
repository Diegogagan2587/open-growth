# frozen_string_literal: true

class Ai::Agents::Proposal < ApplicationRecord
  self.table_name = "ai_agents_proposals"

  STATUSES = %w[pending approved rejected].freeze
  KINDS = %w[financial_transaction].freeze
  PROPOSABLE_ASSOCIATIONS = { "financial_transaction" => :financial_transaction_proposal }.freeze

  class Conflict < StandardError; end

  belongs_to :account, class_name: "::Account"
  belongs_to :reporting_turn, class_name: "Reporting::Turn"
  has_one :financial_transaction_proposal, class_name: "Ai::Agents::Financial::TransactionProposal",
    foreign_key: :proposal_id, dependent: :destroy, inverse_of: :proposal

  validates :status, inclusion: { in: STATUSES }
  validates :kind, inclusion: { in: KINDS }
  validate :reporting_turn_belongs_to_account
  before_update :preserve_identity_and_lifecycle

  scope :pending, -> { where(status: "pending") }

  def pending? = status == "pending"
  def approved? = status == "approved"
  def rejected? = status == "rejected"

  def approve!
    with_lock do
      raise ActiveRecord::RecordNotFound unless status == "pending"

      update!(status: "approved")
      proposalable.apply!
    end
  end

  def reject!
    with_lock do
      raise ActiveRecord::RecordNotFound unless status == "pending"

      update!(status: "rejected")
    end
  end

  private

  def proposalable
    public_send(PROPOSABLE_ASSOCIATIONS.fetch(kind)) || raise(ActiveRecord::RecordNotFound)
  end

  def reporting_turn_belongs_to_account
    return unless reporting_turn && reporting_turn.conversation.account_id != account_id

    errors.add(:reporting_turn, "must belong to the same account")
  end

  def preserve_identity_and_lifecycle
    if %w[account_id reporting_turn_id kind].any? { |attribute| will_save_change_to_attribute?(attribute) }
      errors.add(:base, "A proposal's identity cannot be changed")
    end
    if will_save_change_to_status? && !(status_in_database == "pending" && status.in?(%w[approved rejected]))
      errors.add(:status, "cannot transition from #{status_in_database} to #{status}")
    end

    throw :abort if errors.any?
  end
end
