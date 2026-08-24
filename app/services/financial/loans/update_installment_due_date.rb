module Financial
  module Loans
    class UpdateInstallmentDueDate
      Result = Data.define(:success?, :error_message, :installment, :impact)

      def self.call(installment:, due_date:, update_planned_transaction: false, expected_updated_at: nil)
        new(installment:, due_date:, update_planned_transaction:, expected_updated_at:).call
      end

      def initialize(installment:, due_date:, update_planned_transaction: false, expected_updated_at: nil)
        @installment = installment
        @due_date = due_date.to_date
        @update_planned_transaction = ActiveModel::Type::Boolean.new.cast(update_planned_transaction)
        @expected_updated_at = expected_updated_at.presence
      end

      def call
        installment.with_lock do
          ensure_current_state!
          ensure_due_date_order!
          planned = installment.planned_transaction
          if update_planned_transaction && planned && planned.execution_status != "pending"
            raise ArgumentError, "The linked planned transaction is no longer pending; review the installment again."
          end

          ActiveRecord::Base.transaction do
            installment.update!(due_date: due_date, manual_due_date: true)
            planned.update!(planned_for: due_date, due_date: due_date) if update_planned_transaction && planned
          end
        end

        Result.new(success?: true, error_message: nil, installment: installment.reload, impact: impact)
      rescue ActiveRecord::RecordInvalid, ArgumentError => error
        Result.new(success?: false, error_message: error.message, installment: installment, impact: impact)
      end

      private

      attr_reader :installment, :due_date, :expected_updated_at

      def ensure_current_state!
        return if expected_updated_at.blank?
        return if Time.iso8601(expected_updated_at).to_f == installment.updated_at.to_f

        raise ArgumentError, "This installment changed since the form was opened; review the installment again."
      end

      def ensure_due_date_order!
        previous = installment.financial_loan.installments
          .where("installment_number < ?", installment.installment_number)
          .order(installment_number: :desc).first
        following = installment.financial_loan.installments
          .where("installment_number > ?", installment.installment_number)
          .order(:installment_number).first

        if previous && due_date <= previous.due_date
          raise ArgumentError, "Due date must be after installment ##{previous.installment_number}."
        end
        if following && due_date >= following.due_date
          raise ArgumentError, "Due date must be before installment ##{following.installment_number}."
        end
      end

      def update_planned_transaction
        @update_planned_transaction
      end

      def impact
        planned = installment.planned_transaction
        {
          installment: { id: installment.id, current_due_date: installment.due_date, proposed_due_date: due_date },
          planned_transaction: planned && { id: planned.id, current_due_date: planned.due_date, proposed_due_date: due_date, eligible: planned.execution_status == "pending" },
          actual_payment_preserved: installment.payment_entry.present?
        }
      end
    end
  end
end
