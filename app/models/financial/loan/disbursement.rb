class Financial::Loan::Disbursement
  Result = Struct.new(:success?, :error_message, :transaction, keyword_init: true) do
    alias_method :entry, :transaction
  end

  def self.create(loan:, plan:)
    transaction = nil
    loan.with_lock do
      existing = loan.transactions.find_by(transaction_type: "loan_disbursement")
      return Result.new(success?: true, transaction: existing) if existing

      validate_disbursement!(loan)

      source = loan.funding_sources.first_or_create!(
        account: loan.account,
        financial_plan: plan,
        description: loan.name,
        expected_amount: loan.principal_amount,
        expected_date: plan.planned_for,
        expected_destination_account: loan.destination_account,
        kind: "borrowed"
      )
      result = Financial::FundingSources::Receipt.create(funding_source: source)
      unless result.success?
        loan.errors.add(:base, result.error_message)
        raise ActiveRecord::RecordInvalid, loan
      end

      transaction = result.transaction
      loan.update!(lifecycle_status: "active")
    end
    Result.new(success?: true, transaction: transaction)
  rescue ActiveRecord::RecordInvalid, ActiveRecord::RecordNotUnique => error
    existing = loan&.reload&.transactions&.find_by(transaction_type: "loan_disbursement")
    return Result.new(success?: true, transaction: existing) if existing

    Result.new(success?: false, error_message: error.message)
  end

  def self.validate_disbursement!(loan)
    loan.errors.add(:lifecycle_status, "must be simulated before disbursement") unless loan.lifecycle_status == "simulated"
    loan.errors.add(:liability_account, "must be a liability account") unless loan.liability_account&.liability?
    loan.errors.add(:destination_account, "must be an asset account") unless loan.destination_account&.asset?
    raise ActiveRecord::RecordInvalid, loan if loan.errors.any?
  end
  private_class_method :validate_disbursement!

  def self.destroy(loan:)
    loan.with_lock do
      transaction = loan.transactions.find_by(transaction_type: "loan_disbursement")
      transaction&.remove!
    end
    Result.new(success?: true)
  rescue ActiveRecord::RecordInvalid => error
    Result.new(success?: false, error_message: error.message)
  end
end
