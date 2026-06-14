module Expenses
  class RecordExecutionService
    Result = Struct.new(:success?, :error_message, :expense, :entry, keyword_init: true)

    def self.call(...)
      new(...).call
    end

    def initialize(expense:, source_selection: nil, destination_selection: nil, financial_account_id: nil, financial_liability_id: nil)
      @expense = expense
      @source_selection = source_selection
      @destination_selection = destination_selection
      @financial_account_id = financial_account_id
      @financial_liability_id = financial_liability_id
    end

    def call
      return failure("Expense is required") if expense.blank?
      expense.financial_account = asset_account if asset_account.present?
      expense.financial_liability = liability if liability.present?
      expense.source_selection = source_selection if source_selection.present?
      expense.destination_selection = destination_selection

      result = Financial::Entries::RecordExpenseService.call(
        account: expense.account,
        amount: expense.amount,
        entry_date: expense.date,
        description: expense.description,
        category_id: expense.category_id,
        budget_period_id: expense.budget_period_id,
        source_selection: expense.source_selection,
        destination_selection: expense.destination_selection,
        income_event_id: expense.income_event_id,
        planned_expense_id: expense.planned_expense_id
      )

      return failure(result.error_message) unless result.success?

      Result.new(success?: true, expense: expense, entry: result.entry)
    rescue ActiveRecord::RecordInvalid => e
      failure(e.record.errors.full_messages.to_sentence)
    end

    private

    attr_reader :expense, :source_selection, :destination_selection, :financial_account_id, :financial_liability_id

    def asset_account
      @asset_account ||= Financial::Asset.for_account(expense.account).find_by(id: financial_account_id)
    end

    def liability
      @liability ||= Financial::Liability.for_account(expense.account).find_by(id: financial_liability_id)
    end

    def build_entry
      if expense.transfer?
        Financial::Entry.create!(
          account: expense.account,
          financial_account: expense.financial_account,
          counterparty_financial_account: expense.counterparty_financial_account,
          expense: expense,
          income_event: expense.income_event,
          entry_type: "transfer",
          entry_date: expense.date,
          amount: expense.amount,
          description: expense.description
        )
      elsif expense.debt_payment?
        Financial::Entry.create!(
          account: expense.account,
          financial_account: expense.financial_account,
          financial_liability: expense.counterparty_financial_liability,
          expense: expense,
          income_event: expense.income_event,
          entry_type: "liability_payment",
          entry_date: expense.date,
          amount: expense.amount,
          description: expense.description
        )
      elsif expense.financial_liability.present?
        Financial::Entry.create!(
          account: expense.account,
          financial_liability: expense.financial_liability,
          expense: expense,
          income_event: expense.income_event,
          entry_type: "liability_charge",
          entry_date: expense.date,
          amount: expense.amount,
          description: expense.description
        )
      elsif expense.financial_account.present?
        Financial::Entry.create!(
          account: expense.account,
          financial_account: expense.financial_account,
          expense: expense,
          income_event: expense.income_event,
          entry_type: "outflow",
          entry_date: expense.date,
          amount: expense.amount,
          description: expense.description
        )
      end
    end

    def failure(message)
      Result.new(success?: false, error_message: message)
    end
  end
end
