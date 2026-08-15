module Financial
  module PlannedTransactions
    class ApplyService
      def self.call(planned_transaction:, amount: nil, interest_amount: nil, entry_date: nil, description: nil, category: nil,
        financial_account: nil, counterparty_financial_account: nil, financial_liability: nil)
        unless planned_transaction
          return Execution::Result.new(success?: false, error_message: "Planned transaction is required", transaction: nil)
        end

        installment = Financial::LoanInstallment.find_by(planned_transaction: planned_transaction)
        if installment
          return Financial::Loans::ApplyInstallmentPayment.call(
            installment: installment,
            total: amount || planned_transaction.amount,
            interest: interest_amount.presence || installment.expected_interest,
            entry_date: entry_date || planned_transaction.planned_for || planned_transaction.due_date || Date.current
          )
        end

        source_account = financial_account || (financial_liability if planned_transaction.kind == "liability_charge")
        destination_account = counterparty_financial_account || (financial_liability if planned_transaction.kind == "liability_payment")

        Execution.create(
          planned_transaction: planned_transaction,
          attributes: {
            amount: amount,
            transaction_date: entry_date,
            description: description,
            category_id: category&.id,
            source_account_id: source_account&.id,
            destination_account_id: destination_account&.id
          }
        )
      end
    end
  end
end
