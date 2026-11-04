# frozen_string_literal: true

class Ai::Agents::FinancialAnalyst
  ENTRY_PROPERTIES = {
    entry_type: { type: "string", enum: Financial::Entry::ENTRY_TYPES }, entry_date: { type: "string" }, entry_time: { type: "string" },
    amount: { type: "number" }, description: { type: "string" }, notes: { type: "string" },
    category_id: { type: "integer" }, financial_account_id: { type: "integer" },
    counterparty_financial_account_id: { type: "integer" }, financial_liability_id: { type: "integer" },
    counterparty_financial_liability_id: { type: "integer" }
  }.freeze

  TOOLS = [
    { type: "function", name: "search_transactions", description: "Read transactions and balances for a date range.", strict: false,
      parameters: { type: "object", properties: { from: { type: "string" }, to: { type: "string" }, financial_account_id: { type: "integer" } }, required: %w[from to], additionalProperties: false } },
    { type: "function", name: "list_plans", description: "Read financial plans and their planned transactions.", strict: false,
      parameters: { type: "object", properties: { status: { type: "string", enum: Financial::Plan::LIFECYCLE_STATUSES } }, required: [], additionalProperties: false } },
    { type: "function", name: "list_transaction_options", description: "List this account's category IDs and active expense sources with the correct entry fields for preparing an expense.", strict: false,
      parameters: { type: "object", properties: {}, required: [], additionalProperties: false } },
    { type: "function", name: "propose_transaction", description: "Prepare a new transaction for user approval. Never persists it.", strict: false,
      parameters: { type: "object", properties: ENTRY_PROPERTIES, required: %w[entry_type entry_date amount description], additionalProperties: false } },
    { type: "function", name: "propose_transaction_edit", description: "Prepare a transaction edit for user approval. Never persists it.", strict: false,
      parameters: { type: "object", properties: ENTRY_PROPERTIES.merge(id: { type: "integer" }), required: [ "id" ], additionalProperties: false } }
  ].freeze

  def self.tools = TOOLS

  def initialize(turn:)
    @turn = turn
  end

  def call(name, arguments)
    args = JSON.parse(arguments).symbolize_keys
    case name
    when "search_transactions" then search_transactions(args)
    when "list_plans" then Financial::Plan.advice_summaries(account:, status: args[:status])
    when "list_transaction_options" then Financial::Entry.transaction_options(account:)
    when "propose_transaction" then propose("create", args)
    when "propose_transaction_edit" then propose("edit", args)
    else { error: "Unknown tool" }
    end
  rescue ActiveRecord::RecordInvalid => error
    { error: error.record.errors.full_messages.to_sentence }
  rescue ActiveRecord::RecordNotFound => error
    { error: error.message }
  rescue Financial::EntryProposal::Conflict, ArgumentError, JSON::ParserError => error
    { error: error.message }
  end

  private

  attr_reader :turn

  def account = turn.conversation.account

  def search_transactions(args)
    from = Date.iso8601(args.fetch(:from))
    to = Date.iso8601(args.fetch(:to))
    raise ArgumentError, "End date must be on or after start date" if to < from
    raise ArgumentError, "Date range cannot exceed 366 days" if (to - from).to_i > 365

    Financial::Entry.reconciliation_snapshot(account:, from:, to:, financial_account_id: args[:financial_account_id])
  end

  def propose(action, args)
    proposal = Financial::EntryProposal.propose!(
      reporting_turn: turn,
      action:,
      attributes: args.except(:id),
      financial_entry_id: args[:id]
    )
    { proposal_created: true, proposal_id: proposal.id, action: proposal.action,
      financial_entry_id: proposal.financial_entry_id,
      attributes: proposal.proposed_attributes, message: "A preview is awaiting user approval. It has not been saved." }
  end
end
