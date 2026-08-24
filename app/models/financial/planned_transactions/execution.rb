class Financial::PlannedTransactions::Execution
  OVERRIDABLE_ATTRIBUTES = %i[amount transaction_date description category_id source_account_id destination_account_id].freeze

  Result = Struct.new(:success?, :error_message, :transaction, keyword_init: true) do
    alias_method :entry, :transaction
  end

  def self.create(planned_transaction:, attributes: {})
    actual = nil
    planned_transaction.with_lock do
      actual = planned_transaction.actual_transaction
      return Result.new(success?: true, transaction: actual) if actual
      return Result.new(success?: false, error_message: "Only pending transactions can be executed") unless planned_transaction.execution_status == "pending"

      installment = Financial::Loan::Installment.find_by(planned_transaction: planned_transaction)
      overrides = attributes.to_h.symbolize_keys.slice(*OVERRIDABLE_ATTRIBUTES).compact
      actual = Financial::Transaction.create!(
        {
          account: planned_transaction.account,
          plan: planned_transaction.plan,
          planned_transaction: planned_transaction,
          budget_period: planned_transaction.plan&.budget_period,
          transaction_type: transaction_type_for(planned_transaction.kind),
          transaction_date: planned_transaction.planned_execution_date || planned_transaction.due_date || Date.current,
          amount: planned_transaction.planned_amount,
          description: planned_transaction.description,
          category: planned_transaction.category,
          source_account: planned_transaction.source_account,
          destination_account: planned_transaction.destination_account,
          financial_loan: installment&.financial_loan
        }.merge(overrides)
      )
      planned_transaction.update!(execution_status: "applied")
      installment&.update!(payment_transaction: actual, resolution: "paid")
    end
    Result.new(success?: true, transaction: actual)
  rescue ActiveRecord::RecordInvalid, ActiveRecord::RecordNotUnique => error
    existing = planned_transaction&.reload&.actual_transaction
    return Result.new(success?: true, transaction: existing) if existing

    Result.new(success?: false, error_message: error.message)
  end

  def self.destroy(planned_transaction:)
    planned_transaction.with_lock do
      planned_transaction.actual_transaction&.remove!
      planned_transaction.update!(execution_status: "pending")
    end
    Result.new(success?: true)
  rescue ActiveRecord::RecordInvalid => error
    Result.new(success?: false, error_message: error.message)
  end

  def self.transaction_type_for(kind)
    { "outflow" => "expense", "liability_charge" => "expense", "liability_payment" => "debt_payment" }.fetch(kind, kind)
  end
  private_class_method :transaction_type_for
end
