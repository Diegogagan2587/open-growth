module Financial
  module Loans
    class PlanInstallmentService
      Result = Struct.new(:success?, :error_message, :planned_transaction, keyword_init: true)

      def self.call(installment:, plan:, source_account:)
        transaction = nil
        installment.with_lock do
          transaction = installment.planned_transaction || Financial::PlannedTransaction.create!(
            account: installment.account,
            plan: plan,
            description: "#{installment.financial_loan.name} installment ##{installment.installment_number}",
            planned_amount: installment.expected_amount,
            planned_execution_date: installment.due_date,
            due_date: installment.due_date,
            kind: "liability_payment",
            importance: "essential",
            execution_status: "pending",
            source_account: source_account,
            destination_account: installment.financial_loan.liability_account
          )
          installment.update!(planned_transaction: transaction)
        end
        Result.new(success?: true, planned_transaction: transaction)
      rescue ActiveRecord::RecordInvalid, ActiveRecord::RecordNotUnique => error
        Result.new(success?: false, error_message: error.message, planned_transaction: installment&.reload&.planned_transaction)
      end
    end
  end
end
