class Financial::Loans::ApplyInstallmentPayment
  Result = Data.define(:success?, :error_message, :entry)

  def self.call(...)
    new(...).call
  end

  def initialize(installment:, total:, interest:, entry_date:)
    @installment = installment
    @breakdown = Financial::Loans::PaymentBreakdown.new(total: total, interest: interest)
    @entry_date = entry_date.to_date
  end

  def call
    payment_entry = installment.with_lock do
      next installment.payment_entry if installment.payment_entry

      transaction = installment.planned_transaction
      raise ArgumentError, "Installment must be added to a plan before payment" unless transaction
      raise ArgumentError, "Only pending installments can be paid" unless transaction.execution_status == "pending"
      raise ArgumentError, "Select an interest category on the loan" if breakdown.interest.positive? && loan.interest_category.blank?

      ActiveRecord::Base.transaction do
        interest_entry = create_interest_entry(transaction)
        payment = create_payment_entry(transaction)
        transaction.update!(execution_status: "applied", status: "paid", applied_on: entry_date)
        installment.update!(interest_entry: interest_entry, payment_entry: payment, resolution: "paid")
        payment
      end
    end

    Result.new(success?: true, error_message: nil, entry: payment_entry)
  rescue ActiveRecord::RecordInvalid, ActiveRecord::RecordNotUnique, ArgumentError => error
    existing = installment&.reload&.payment_entry
    return Result.new(success?: true, error_message: nil, entry: existing) if existing

    Result.new(success?: false, error_message: error.message, entry: nil)
  end

  private

  attr_reader :installment, :breakdown, :entry_date

  def loan
    installment.financial_loan
  end

  def create_interest_entry(transaction)
    return nil if breakdown.interest.zero?

    Financial::Entry.create!(
      account: installment.account,
      financial_loan: loan,
      financial_liability: loan.liability,
      income_event: transaction.plan,
      budget_period: transaction.plan&.budget_period,
      category: loan.interest_category,
      entry_type: "liability_charge",
      entry_date: entry_date,
      amount: breakdown.interest,
      description: "#{loan.name} installment ##{installment.installment_number} interest"
    )
  end

  def create_payment_entry(transaction)
    Financial::Entry.create!(
      account: installment.account,
      financial_loan: loan,
      financial_liability: loan.liability,
      financial_account: transaction.financial_account,
      income_event: transaction.plan,
      budget_period: transaction.plan&.budget_period,
      planned_expense: transaction,
      entry_type: "liability_payment",
      entry_date: entry_date,
      amount: breakdown.total,
      description: transaction.description
    )
  end
end
