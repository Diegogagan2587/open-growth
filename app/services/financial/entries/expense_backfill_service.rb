    class Financial::Entries::ExpenseBackfillService
      Result = Struct.new(:created, :updated, :skipped, :errors, keyword_init: true)

      def self.call(...)
        new(...).call
      end

      def initialize(scope: Expense.all)
        @scope = scope
        @created = 0
        @updated = 0
        @skipped = 0
        @errors = []
      end

      def call
        scope.find_each do |expense|
          backfill_expense(expense)
        end

        Result.new(created: created, updated: updated, skipped: skipped, errors: errors)
      end

      private

      attr_reader :scope, :created, :updated, :skipped, :errors

      def backfill_expense(expense)
        entry = Financial::Entry.find_by(expense_id: expense.id)

        if entry.present?
          changed = hydrate_entry(entry, expense)
          if changed
            entry.save!
            @updated += 1
          else
            @skipped += 1
          end
          return
        end

        entry = Financial::Entry.new
        hydrate_entry(entry, expense)
        entry.save!
        @created += 1
      rescue ActiveRecord::RecordInvalid => e
        @errors << "Expense ##{expense.id}: #{e.record.errors.full_messages.to_sentence}"
      end

      def hydrate_entry(entry, expense)
        changed = false

        attrs = {
          account: expense.account,
          expense: expense,
          income_event: expense.income_event,
          planned_expense: expense.planned_expense,
          entry_date: expense.date,
          amount: expense.amount,
          description: expense.description,
          category: expense.category,
          budget_period: expense.budget_period,
          financial_account: expense.financial_account || expense.planned_expense&.financial_account,
          counterparty_financial_account: expense.counterparty_financial_account || expense.planned_expense&.counterparty_financial_account
        }

        entry_type, liability = mapped_type_and_liability(expense)
        attrs[:entry_type] = entry_type
        attrs[:financial_liability] = liability

        attrs.each do |key, value|
          current = entry.public_send(key)
          next if current.present?
          entry.public_send("#{key}=", value)
          changed = true
        end

        changed
      end

      def mapped_type_and_liability(expense)
        planned_expense = expense.planned_expense

        return [ "transfer", nil ] if expense.transfer? || planned_expense&.transfer?
        return [ "liability_payment", expense.counterparty_financial_liability || planned_expense&.financial_liability ] if expense.debt_payment? || planned_expense&.debt_payment?
        return [ "liability_charge", expense.financial_liability || planned_expense&.financial_liability ] if expense.financial_liability.present? || planned_expense&.financial_liability.present?

        [ "outflow", nil ]
      end
    end
