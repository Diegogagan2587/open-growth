class Financial::Loans::RepaymentTerms
  BASES = %w[annual_rate payment_amounts].freeze
  PERIODS_PER_YEAR = {
    "weekly" => 52.to_d,
    "biweekly" => 26.to_d,
    "quincenal" => (365.to_d / 15),
    "monthly" => 12.to_d
  }.freeze

  attr_reader :principal, :number_of_payments, :payment_frequency, :repayment_basis,
    :annual_rate, :regular_payment, :final_payment

  def initialize(principal:, number_of_payments:, payment_frequency:, repayment_basis:,
    annual_rate: nil, regular_payment: nil, final_payment: nil)
    @principal = principal.to_d
    @number_of_payments = number_of_payments.to_i
    @payment_frequency = payment_frequency.to_s
    @repayment_basis = repayment_basis.to_s
    @annual_rate = annual_rate.presence&.to_d
    @regular_payment = regular_payment.presence&.to_d
    @final_payment = final_payment.presence&.to_d

    validate!
    @annual_rate = inferred_annual_rate if payment_amounts?
    freeze
  end

  def annual_rate?
    repayment_basis == "annual_rate"
  end

  def payment_amounts?
    repayment_basis == "payment_amounts"
  end

  def interest_rate_estimated?
    payment_amounts?
  end

  def periods_per_year
    PERIODS_PER_YEAR.fetch(payment_frequency)
  end

  def periodic_rate
    (annual_rate / 100) / periods_per_year
  end

  def contractual_payments
    return [] unless payment_amounts?

    Array.new(number_of_payments) do |index|
      index == number_of_payments - 1 && final_payment ? final_payment : regular_payment
    end
  end

  def total_repayment
    payment_amounts? ? contractual_payments.sum(0.to_d) : nil
  end

  private

  def validate!
    raise ArgumentError, "Principal must be greater than 0" unless principal.positive?
    raise ArgumentError, "Number of payments must be greater than 0" unless number_of_payments.positive?
    raise ArgumentError, "Payment frequency is not supported" unless PERIODS_PER_YEAR.key?(payment_frequency)
    raise ArgumentError, "Repayment basis is not supported" unless BASES.include?(repayment_basis)

    if annual_rate?
      raise ArgumentError, "Annual interest rate is required" if annual_rate.nil?
      raise ArgumentError, "Annual interest rate cannot be negative" if annual_rate.negative?
    else
      raise ArgumentError, "Regular payment must be greater than 0" unless regular_payment&.positive?
      raise ArgumentError, "Final payment must be greater than 0" if final_payment && !final_payment.positive?
      raise ArgumentError, "Payment amounts do not repay the principal" if contractual_payments.sum(0.to_d) < principal
    end
  end

  def inferred_annual_rate
    payments = contractual_payments
    return 0.to_d if payments.sum(0.to_d) == principal

    low = 0.0
    high = 1.0
    high *= 2 while present_value(payments, high) > principal

    80.times do
      midpoint = (low + high) / 2.0
      if present_value(payments, midpoint) > principal
        low = midpoint
      else
        high = midpoint
      end
    end

    (((low + high) / 2.0).to_d * periods_per_year * 100).round(3)
  end

  def present_value(payments, rate)
    payments.each_with_index.sum { |payment, index| payment.to_f / ((1 + rate)**(index + 1)) }
  end
end
