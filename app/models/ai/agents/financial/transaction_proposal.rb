# frozen_string_literal: true

class Ai::Agents::Financial::TransactionProposal < ApplicationRecord
  self.table_name = "ai_agents_financial_transaction_proposals"

  ACTIONS = %w[create edit].freeze
  EDITABLE_ATTRIBUTES = %w[entry_type entry_date entry_time amount description notes category_id financial_account_id
    counterparty_financial_account_id financial_liability_id counterparty_financial_liability_id].freeze

  class Conflict < StandardError; end

  belongs_to :proposal, class_name: "Ai::Agents::Proposal", inverse_of: :financial_transaction_proposal
  belongs_to :financial_entry, class_name: "Financial::Entry", optional: true, inverse_of: :transaction_proposals

  validates :action, inclusion: { in: ACTIONS }
  validates :proposed_attributes, presence: true
  validates :proposal_id, uniqueness: true
  validate :proposal_is_a_financial_transaction
  validate :associations_belong_to_account
  validate :proposed_entry_is_valid
  before_update :preserve_proposal_and_application

  def self.propose!(reporting_turn:, action:, attributes:, financial_entry_id: nil)
    raise ArgumentError, "Unsupported proposal action" unless action.in?(ACTIONS)

    account = reporting_turn.conversation.account
    attributes = attributes.stringify_keys.slice(*EDITABLE_ATTRIBUTES)
    raise ArgumentError, "A transaction change must include at least one field" if attributes.blank?

    before_attributes = nil
    entry = if action == "create"
      account.financial_entries.new(attributes)
    else
      account.financial_entries.find(financial_entry_id).tap do |record|
        before_attributes = attributes_snapshot(record)
        record.assign_attributes(attributes)
      end
    end
    raise ActiveRecord::RecordInvalid.new(entry) unless entry.valid?

    transaction_proposal = nil
    reporting_turn.conversation.with_lock do
      if account.ai_agent_proposals.pending.joins(:reporting_turn)
          .where(reporting_turns: { conversation_id: reporting_turn.conversation_id }).exists?
        raise Ai::Agents::Proposal::Conflict, "Resolve the existing transaction proposal in this conversation first"
      end

      Ai::Agents::Proposal.transaction do
        proposal = Ai::Agents::Proposal.create!(
          account: account,
          reporting_turn: reporting_turn,
          kind: "financial_transaction"
        )
        transaction_proposal = create!(
          proposal: proposal,
          financial_entry: (entry if action == "edit"),
          action: action,
          proposed_attributes: attributes,
          before_attributes: before_attributes
        )
      end
    end
    transaction_proposal
  end

  def self.attributes_snapshot(entry)
    EDITABLE_ATTRIBUTES.index_with do |field|
      value = entry.public_send(field)
      if field == "entry_time"
        value&.strftime("%H:%M")
      else
        case value
        when Date then value.iso8601
        when BigDecimal then value.to_s("F")
        else value
        end
      end
    end
  end

  def apply!
    ensure_category_belongs_to_account!

    if action == "create"
      entry = account.financial_entries.create!(permitted_attributes)
      update!(financial_entry: entry)
      entry
    else
      target = account.financial_entries.lock.find_by!(id: financial_entry_id)
      raise Conflict, "This transaction changed after the preview. Review it again before applying this edit." unless self.class.attributes_snapshot(target) == before_attributes

      target.update!(permitted_attributes)
      target
    end
  end

  private

  def account
    proposal.account
  end

  def proposal_is_a_financial_transaction
    return if proposal.blank? || proposal.kind == "financial_transaction"

    errors.add(:proposal, "must be a financial transaction proposal")
  end

  def permitted_attributes
    proposed_attributes.slice(*EDITABLE_ATTRIBUTES).symbolize_keys
  end

  def associations_belong_to_account
    if financial_entry && financial_entry.account_id != account.id
      errors.add(:financial_entry, "must belong to the same account")
    end
    if action == "create" && financial_entry.present? && proposal&.pending?
      errors.add(:financial_entry, "must be blank for a create proposal")
    elsif action == "edit" && financial_entry.blank?
      errors.add(:financial_entry, "is required for an edit proposal")
    end

    category_id = proposed_attributes["category_id"] || proposed_attributes[:category_id]
    if category_id.present? && !Category.for_account(account).exists?(id: category_id)
      errors.add(:proposed_attributes, "category must belong to the same account")
    end
  end

  def proposed_entry_is_valid
    return unless proposal&.pending? && account && action.in?(ACTIONS)

    entry = action == "edit" ? financial_entry : account.financial_entries.new
    return unless entry

    entry.assign_attributes(permitted_attributes)
    errors.add(:base, entry.errors.full_messages.to_sentence) unless entry.valid?
  end

  def ensure_category_belongs_to_account!
    category_id = proposed_attributes["category_id"] || proposed_attributes[:category_id]
    return if category_id.blank? || Category.for_account(account).exists?(id: category_id)

    raise Conflict, "The selected category is no longer available for this account."
  end

  def preserve_proposal_and_application
    fields = %w[proposal_id action proposed_attributes before_attributes]
    if fields.any? { |attribute| will_save_change_to_attribute?(attribute) }
      errors.add(:base, "A transaction proposal cannot be changed after it is created")
    end
    if will_save_change_to_financial_entry_id? && !(proposal&.approved? && action == "create" && financial_entry_id_in_database.nil? && financial_entry_id.present?)
      errors.add(:financial_entry, "cannot be changed unless its create proposal is being applied")
    end

    throw :abort if errors.any?
  end
end
