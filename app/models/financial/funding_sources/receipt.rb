class Financial::FundingSources::Receipt
  Result = Struct.new(:success?, :error_message, :transaction, keyword_init: true) do
    alias_method :entry, :transaction
  end

  def self.create(funding_source:, amount: nil, transaction_date: nil, description: nil)
    transaction = nil
    funding_source.with_lock do
      transaction = funding_source.receipt_transaction || Financial::Transaction.create!(
        account: funding_source.account,
        plan: funding_source.financial_plan,
        funding_source: funding_source,
        financial_loan: funding_source.financial_loan,
        transaction_type: funding_source.kind == "borrowed" ? "loan_disbursement" : funding_source.kind == "refund" ? "refund" : "income",
        transaction_date: transaction_date.presence || funding_source.expected_date,
        amount: amount.presence || funding_source.expected_amount,
        description: description.presence || funding_source.description,
        source_account: funding_source.financial_loan&.liability_account,
        destination_account: funding_source.expected_destination_account
      )
      funding_source.resolve_from!(transaction)
    end
    Result.new(success?: true, transaction: transaction)
  rescue ActiveRecord::RecordInvalid, ActiveRecord::RecordNotUnique => error
    existing = funding_source&.reload&.receipt_transaction
    return Result.new(success?: true, transaction: existing) if existing

    Result.new(success?: false, error_message: error.message)
  end

  def self.destroy(funding_source:)
    funding_source.with_lock do
      funding_source.receipt_transaction&.remove!
      funding_source.update!(resolution: "pending")
    end
    Result.new(success?: true)
  rescue ActiveRecord::RecordInvalid => error
    Result.new(success?: false, error_message: error.message)
  end

end
