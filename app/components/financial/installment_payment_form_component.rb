# frozen_string_literal: true

class Financial::InstallmentPaymentFormComponent < ViewComponent::Base
  def initialize(transaction:, entry_date: nil)
    @transaction = transaction
    @entry_date = entry_date || transaction.planned_for || transaction.due_date || Date.current
    @installment = Financial::Loan::Installment.includes(:financial_loan).find_by(planned_transaction_id: transaction.id)
  end

  private

  attr_reader :transaction, :entry_date, :installment
end
