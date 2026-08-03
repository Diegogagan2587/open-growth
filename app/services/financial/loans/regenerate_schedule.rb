class Financial::Loans::RegenerateSchedule
  Result = Data.define(:success?, :error_message, :installments)

  def self.call(...)
    new(...).call
  end

  def initialize(loan:, start_date:)
    @loan = loan
    @start_date = start_date.to_date
  end

  def call
    installments = loan.with_lock do
      terms = loan.repayment_terms
      paid = loan.installments.where(resolution: "paid").order(:installment_number).to_a
      ensure_removable_extras!(terms.number_of_payments)

      projections = Financial::Loans::AmortizationSchedule.build(
        terms: terms,
        start_date: start_date,
        paid_installments: paid
      )

      ActiveRecord::Base.transaction do
        reconciled = projections.map { |projection| reconcile(projection) }
        loan.installments.where("installment_number > ?", terms.number_of_payments).delete_all
        paid + reconciled
      end
    end

    Result.new(success?: true, error_message: nil, installments: installments)
  rescue ActiveRecord::RecordInvalid, ActiveRecord::RecordNotUnique, ArgumentError => error
    Result.new(success?: false, error_message: error.message, installments: [])
  end

  private

  attr_reader :loan, :start_date

  def ensure_removable_extras!(number_of_payments)
    protected_extra = loan.installments
      .where("installment_number > ?", number_of_payments)
      .where("planned_transaction_id IS NOT NULL OR payment_entry_id IS NOT NULL OR resolution = 'paid'")
      .exists?
    raise ArgumentError, "Payment count cannot remove a planned or paid installment" if protected_extra
  end

  def reconcile(projection)
    installment = loan.installments.find_or_initialize_by(installment_number: projection.installment_number)
    raise ArgumentError, "Paid installments cannot be regenerated" if installment.resolution == "paid"

    installment.assign_attributes(
      account: loan.account,
      due_date: projection.due_date,
      expected_amount: projection.amount,
      expected_principal: projection.principal,
      expected_interest: projection.interest,
      resolution: "scheduled"
    )
    installment.save!
    sync_pending_plan!(installment)
    installment
  end

  def sync_pending_plan!(installment)
    transaction = installment.planned_transaction
    return unless transaction
    raise ArgumentError, "Only pending installment plans can be synchronized" unless transaction.execution_status == "pending"

    transaction.update!(
      amount: installment.expected_amount,
      planned_for: installment.due_date,
      due_date: installment.due_date
    )
  end
end
