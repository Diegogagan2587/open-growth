class Financial::Loan::AmortizationSchedule
  Row = Data.define(:number, :due_date, :amount, :principal, :interest)
  PERIODS_PER_YEAR = {
    "weekly" => 52.to_d,
    "biweekly" => 26.to_d,
    "quincenal" => (365.to_d / 15),
    "monthly" => 12.to_d
  }.freeze

  def self.for(loan, start_date:)
    new(loan, start_date:).rows
  end

  def initialize(loan, start_date:)
    @loan = loan
    @start_date = start_date.to_date
  end

  def rows
    raise ArgumentError, "Number of payments and payment frequency are required" unless loan.number_of_payments.to_i.positive? && PERIODS_PER_YEAR.key?(loan.payment_frequency)

    remaining = loan.principal_amount.to_d
    payment = loan.payment_amount.presence&.to_d || amortized_payment(remaining)

    (1..loan.number_of_payments).map do |number|
      interest = (remaining * periodic_rate).round(2)
      principal = number == loan.number_of_payments ? remaining : [ payment - interest, remaining ].min.round(2)
      amount = (principal + interest).round(2)
      remaining = (remaining - principal).round(2)
      Row.new(number:, due_date: due_date_for(number), amount:, principal:, interest:)
    end
  end

  private

  attr_reader :loan, :start_date

  def periodic_rate
    @periodic_rate ||= (loan.interest_rate.to_d / 100) / PERIODS_PER_YEAR.fetch(loan.payment_frequency)
  end

  def amortized_payment(principal)
    return (principal / loan.number_of_payments).round(2) if periodic_rate.zero?

    (principal * periodic_rate / (1 - (1 + periodic_rate)**(-loan.number_of_payments))).round(2)
  end

  def due_date_for(number)
    case loan.payment_frequency
    when "weekly" then start_date + number.weeks
    when "biweekly" then start_date + (number * 2).weeks
    when "quincenal" then start_date + (number * 15).days
    else start_date.advance(months: number)
    end
  end
end
