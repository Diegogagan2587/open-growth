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

      def initialize(account:, amount:, entry_date:, description:, category_id:, budget_period_id:, source_account_id: nil, destination_account_id: nil, source_selection: nil, destination_selection: nil, income_event_id: nil, planned_expense_id: nil, entry_time: nil)
        @account = account
        @amount = amount
        @entry_date = entry_date
        @description = description
        @category_id = category_id
        @budget_period_id = budget_period_id
        @source_account_id = source_account_id
        @destination_account_id = destination_account_id
        @source_selection = source_selection
        @destination_selection = destination_selection
        @income_event_id = income_event_id
        @planned_expense_id = planned_expense_id
        @entry_time = entry_time
      end

      def call
        return failure("Account is required") if account.blank?
        return failure("Source account must be selected") if source_reference.blank?
        return failure("Source account is invalid") if source_reference.present? && source_account.blank?
        return failure("Destination account is invalid") if destination_reference.present? && destination_account.blank?

        entry = Financial::Transaction.new(base_attributes.merge(
          source_account: source_account,
          destination_account: destination_account
        ))
        entry.save!

        Result.new(success?: true, entry: entry)
      rescue ActiveRecord::RecordInvalid => e
        failure(e.record.errors.full_messages.to_sentence)
      end

      private

      attr_reader :account, :amount, :entry_date, :entry_time, :description, :category_id, :budget_period_id, :source_account_id, :destination_account_id, :source_selection, :destination_selection, :income_event_id, :planned_expense_id

      def base_attributes
        {
          account: account,
          amount: amount,
          transaction_date: entry_date,
          entry_time: entry_time,
          description: description,
          category: Category.for_account(account).find_by(id: category_id),
          budget_period: BudgetPeriod.for_account(account).find_by(id: budget_period_id),
          plan: plan,
          planned_transaction: planned_transaction
        }
      end

      def plan
        return nil if income_event_id.blank?

        @plan ||= Financial::Plan.for_account(account).find_by(id: income_event_id)
      end

      def planned_transaction
        return nil if planned_expense_id.blank?

        @planned_transaction ||= Financial::PlannedTransaction.for_account(account).find_by(id: planned_expense_id)
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
