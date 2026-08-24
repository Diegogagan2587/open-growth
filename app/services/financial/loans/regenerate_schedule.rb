class Financial::Loans::RegenerateSchedule
  Result = Data.define(:success?, :error_message, :installments)

  def self.call(...)
    new(...).call
  end

  def initialize(loan:, start_date: nil, first_payment_date: nil, reset_manual_installment_ids: [])
    @loan = loan
    @start_date = start_date&.to_date
    @first_payment_date = first_payment_date&.to_date || loan.first_payment_date
    @reset_manual_installment_ids = Array(reset_manual_installment_ids).map(&:to_i)
  end

  def call
    installments = loan.regenerate_schedule!(
      start_date: start_date,
      first_payment_date: first_payment_date,
      reset_manual_installment_ids: reset_manual_installment_ids
    )

    Result.new(success?: true, error_message: nil, installments: installments)
  rescue ActiveRecord::RecordInvalid, ActiveRecord::RecordNotUnique, ArgumentError => error
    Result.new(success?: false, error_message: error.message, installments: [])
  end

  private

  attr_reader :loan, :start_date, :first_payment_date, :reset_manual_installment_ids
end
