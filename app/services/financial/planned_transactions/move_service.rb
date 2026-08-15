module Financial
  module PlannedTransactions
    class MoveService
      Result = Struct.new(:success?, :error_message, :planned_transaction, keyword_init: true)

      def self.call(...)
        new(...).call
      end

      def initialize(planned_transaction:, target_plan:)
        @transaction = planned_transaction
        @target_plan = target_plan
      end

      def call
        return failure("Only pending transactions can be moved") unless transaction.execution_status == "pending" && transaction.actual_transaction.blank?
        return failure("Target plan must belong to the same account") if target_plan && target_plan.account_id != transaction.account_id
        return Result.new(success?: true, planned_transaction: transaction) if target_plan&.id == transaction.income_event_id

        transaction.with_lock do
          position = target_plan&.planned_transactions&.maximum(:position).to_i + 1 if target_plan
          transaction.update!(plan: target_plan, position: position)
        end
        Result.new(success?: true, planned_transaction: transaction)
      rescue ActiveRecord::RecordInvalid, ActiveRecord::RecordNotUnique => error
        failure(error.message)
      end

      private

      attr_reader :transaction, :target_plan

      def failure(message)
        Result.new(success?: false, error_message: message, planned_transaction: transaction)
      end
    end
  end
end
