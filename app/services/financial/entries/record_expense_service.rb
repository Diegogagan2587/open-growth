module Financial
  module Entries
    class RecordExpenseService
      Result = Struct.new(:success?, :error_message, :entry, keyword_init: true)

      def self.call(...)
        # construct same instace of this class and call #call
        # to ensure we run all code in the same transaction
        # context
        new(...).call
      end

      def initialize(account:, amount:, entry_date:, description:, category_id:, budget_period_id:, source_selection:, destination_selection: nil, income_event_id: nil, planned_expense_id: nil, entry_time: nil)
        @account = account
        @amount = amount
        @entry_date = entry_date
        @description = description
        @category_id = category_id
        @budget_period_id = budget_period_id
        @source_selection = source_selection
        @destination_selection = destination_selection
        @income_event_id = income_event_id
        @planned_expense_id = planned_expense_id
        @entry_time = entry_time
      end

      def call
        return failure("Account is required") if account.blank?

        entry = Financial::Entry.new(base_attributes)
        apply_routing(entry)
        entry.save!

        Result.new(success?: true, entry: entry)
      rescue ActiveRecord::RecordInvalid => e
        failure(e.record.errors.full_messages.to_sentence)
      end

      private

      attr_reader :account, :amount, :entry_date, :entry_time, :description, :category_id, :budget_period_id, :source_selection, :destination_selection, :income_event_id, :planned_expense_id

      def base_attributes
        {
          account: account,
          amount: amount,
          entry_date: entry_date,
          description: description,
          category: Category.for_account(account).find_by(id: category_id),
          budget_period: BudgetPeriod.for_account(account).find_by(id: budget_period_id),
          income_event: income_event,
          planned_expense: planned_expense
        }
      end

      def income_event
        return nil if income_event_id.blank?

        @income_event ||= IncomeEvent.for_account(account).find_by(id: income_event_id)
      end

      def planned_expense
        return nil if planned_expense_id.blank?

        @planned_expense ||= PlannedExpense.for_account(account).find_by(id: planned_expense_id)
      end

      def apply_routing(entry)
        source_kind, source_id = split_selection(source_selection)
        destination_kind, destination_id = split_selection(destination_selection)

        if source_kind == "liability"
          entry.entry_type = "liability_charge"
          entry.financial_liability = Financial::Liability.for_account(account).find_by(id: source_id)
          return
        end

        source_asset = Financial::Asset.for_account(account).find_by(id: source_id)

        if destination_kind == "asset"
          entry.entry_type = "transfer"
          entry.financial_account = source_asset
          entry.counterparty_financial_account = Financial::Asset.for_account(account).find_by(id: destination_id)
        elsif destination_kind == "liability"
          entry.entry_type = "liability_payment"
          entry.financial_account = source_asset
          entry.financial_liability = Financial::Liability.for_account(account).find_by(id: destination_id)
        else
          entry.entry_type = "outflow"
          entry.financial_account = source_asset
        end
      end

      def split_selection(selection)
        return [ nil, nil ] if selection.blank?

        selection.to_s.split(":", 2)
      end

      def failure(message)
        Result.new(success?: false, error_message: message)
      end
    end
  end
end
