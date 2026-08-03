class Financial::Loans::PaymentBreakdown
  attr_reader :total, :interest, :principal

  def initialize(total:, interest:)
    @total = total.to_d.round(2)
    @interest = interest.to_d.round(2)
    @principal = (@total - @interest).round(2)

    raise ArgumentError, "Payment total must be greater than 0" unless @total.positive?
    raise ArgumentError, "Interest cannot be negative" if @interest.negative?
    raise ArgumentError, "Interest must be less than the payment total" unless @principal.positive?

    freeze
  end
end
