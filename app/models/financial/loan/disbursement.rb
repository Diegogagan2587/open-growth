class Financial::Loan::Disbursement
  Result = Struct.new(:success?, :error_message, :transaction, keyword_init: true) do
    alias_method :entry, :transaction
  end

  def self.create(loan:, plan:)
    transaction = nil
    loan.with_lock do
      loan.update!(lifecycle_status: "active")
      source = loan.funding_sources.first_or_create!(
        account: loan.account,
        financial_plan: plan,
        description: loan.name,
        expected_amount: loan.principal_amount,
        expected_date: plan.planned_for,
        expected_destination_asset: loan.destination_asset,
        expected_destination_liability: loan.destination_liability,
        kind: "borrowed"
      )
      transaction = source.receipt_entry || Financial::Entry.create!(
        account: loan.account,
        income_event: plan,
        funding_source: source,
        financial_loan: loan,
        entry_type: "loan_disbursement",
        entry_date: source.expected_date,
        amount: source.expected_amount,
        description: source.description,
        financial_liability: loan.liability,
        financial_account: loan.destination_asset,
        counterparty_financial_liability: loan.destination_liability
      )
      source.update!(resolution: "received")
    end
    Result.new(success?: true, transaction: transaction)
  rescue ActiveRecord::RecordInvalid, ActiveRecord::RecordNotUnique => error
    existing_transaction = loan&.reload&.entries&.find_by(entry_type: "loan_disbursement")
    return Result.new(success?: true, transaction: existing_transaction) if existing_transaction

    Result.new(success?: false, error_message: error.message)
  end

  def self.destroy(loan:)
    loan.with_lock do
      paid_installments = loan.installments.where("resolution = 'paid' OR payment_entry_id IS NOT NULL OR interest_entry_id IS NOT NULL")
      if loan.entries.where.not(entry_type: "loan_disbursement").exists? || paid_installments.exists?
        return Result.new(success?: false, error_message: "Undo installment payments before undoing the disbursement")
      end

      loan.transaction do
        loan.entries.where(entry_type: "loan_disbursement").each(&:destroy!)
        loan.funding_sources.each(&:destroy!)
        loan.update!(lifecycle_status: "simulated")
      end
    end
    Result.new(success?: true)
  rescue ActiveRecord::RecordInvalid, ActiveRecord::RecordNotDestroyed => error
    Result.new(success?: false, error_message: error.message)
  end
end
