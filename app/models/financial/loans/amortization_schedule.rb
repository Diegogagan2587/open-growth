class Financial::Loans::AmortizationSchedule
  Projection = Data.define(
    :installment_number,
    :due_date,
    :amount,
    :principal,
    :interest
  )

  def self.build(...)
    new(...).projections
  end

  def initialize(terms:, start_date: nil, first_payment_date: nil, paid_installments: [])
    @terms = terms
    @start_date = start_date&.to_date
    @first_payment_date = first_payment_date&.to_date
    @paid_installments = paid_installments.sort_by(&:installment_number)
    validate_paid_prefix!
  end

  def projections
    first_number = paid_installments.length + 1
    return [] if first_number > terms.number_of_payments

    remaining = (terms.principal - paid_installments.sum(0.to_d) { |row| row.expected_principal.to_d }).round(2)
    installments_left = terms.number_of_payments - paid_installments.length
    calculated_payment = amortized_payment(remaining, installments_left) if terms.annual_rate?

    (first_number..terms.number_of_payments).map do |number|
      amount = amount_for(number, calculated_payment, remaining)
      interest = (remaining * terms.periodic_rate).round(2)
      principal = number == terms.number_of_payments ? remaining : (amount - interest).round(2)
      raise ArgumentError, "Installment #{number} payment of #{amount.to_f.round(2)} must be greater than accrued interest of #{interest.to_f.round(2)}; enter at least #{(interest + 0.01).to_f.round(2)}" unless principal.positive?
      raise ArgumentError, "Payment amount exceeds remaining principal" if number != terms.number_of_payments && principal > remaining

      interest = (amount - principal).round(2) if number == terms.number_of_payments
      raise ArgumentError, "Final payment is too low to repay the remaining principal" if interest.negative?

      projection = Projection.new(
        installment_number: number,
        due_date: due_date_for(number),
        amount: amount.round(2),
        principal: principal.round(2),
        interest: interest.round(2)
      )
      remaining = (remaining - principal).round(2)
      projection
    end
  end

  private

  attr_reader :terms, :start_date, :first_payment_date, :paid_installments

  def validate_paid_prefix!
    expected_numbers = (1..paid_installments.length).to_a
    actual_numbers = paid_installments.map(&:installment_number)
    raise ArgumentError, "Paid installments must form a consecutive prefix" unless actual_numbers == expected_numbers
    raise ArgumentError, "Loan has more paid installments than configured payments" if paid_installments.length > terms.number_of_payments
  end

  def amount_for(number, calculated_payment, remaining)
    if terms.payment_amounts?
      terms.contractual_payments.fetch(number - 1)
    elsif number == terms.number_of_payments
      (remaining + (remaining * terms.periodic_rate).round(2)).round(2)
    else
      calculated_payment
    end
  end

  def amortized_payment(principal, periods)
    rate = terms.periodic_rate
    return (principal / periods).round(2) if rate.zero?

    (principal * rate / (1 - (1 + rate)**(-periods))).round(2)
  end

  def due_date_for(number)
    case terms.payment_frequency
    when "weekly" then start_date + number.weeks
    when "biweekly" then start_date + (number * 2).weeks
    when "quincenal" then start_date + (number * 15).days
    else start_date.advance(months: number)
    end
  end
end
