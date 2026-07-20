module Financial
  module PlannedTransactions
    class ApplyService
      Result = Struct.new(:success?, :error_message, :entry, keyword_init: true)

      def self.call(...)
        new(...).call
      end

      def initialize(planned_transaction:, amount: nil, entry_date: nil, description: nil, category: nil,
        financial_account: nil, counterparty_financial_account: nil, financial_liability: nil)
        @transaction = planned_transaction
        @overrides = { amount:, entry_date:, description:, category:, financial_account:, counterparty_financial_account:, financial_liability: }.compact
      end

      def call
        return failure("Planned transaction is required") if transaction.blank?

        entry = nil
        transaction.with_lock do
          entry = transaction.financial_entry
          if entry
            reconcile_installment(entry)
            return Result.new(success?: true, entry: entry)
          end
          return failure("Only pending transactions can be applied") unless transaction.execution_status == "pending"

          entry = Financial::Entry.create!(entry_attributes)
          transaction.update!(execution_status: "applied", status: legacy_applied_status, applied_on: entry.entry_date)
          reconcile_installment(entry)
        end
        Result.new(success?: true, entry: entry)
      rescue ActiveRecord::RecordInvalid, ActiveRecord::RecordNotUnique => error
        existing = transaction&.reload&.financial_entry
        return Result.new(success?: true, entry: existing) if existing

        failure(error.message)
      end

      private

      attr_reader :transaction, :overrides

      def entry_attributes
        installment = Financial::LoanInstallment.find_by(planned_transaction_id: transaction.id)
        {
          account: transaction.account,
          income_event: transaction.income_event,
          planned_expense: transaction,
          budget_period: transaction.income_event&.budget_period,
          entry_type: transaction.kind,
          entry_date: transaction.planned_for || transaction.due_date || Date.current,
          amount: transaction.amount,
          description: transaction.description,
          category: transaction.category,
          financial_account: transaction.financial_account,
          counterparty_financial_account: transaction.counterparty_financial_account,
          financial_liability: transaction.financial_liability,
          financial_loan: installment&.financial_loan
        }.merge(overrides)
      end

      def legacy_applied_status
        transaction.kind == "transfer" ? "transferred" : "paid"
      end

      def reconcile_installment(entry)
        installment = Financial::LoanInstallment.find_by(planned_transaction_id: transaction.id)
        installment&.update!(payment_entry: entry, resolution: "paid")
      end

      def failure(message)
        Result.new(success?: false, error_message: message)
      end
    end
  end
end
