require "test_helper"

class Financial::Loans::PaymentBreakdownTest < ActiveSupport::TestCase
  test "derives principal from total and interest" do
    breakdown = Financial::Loans::PaymentBreakdown.new(total: 1_165, interest: 165)

    assert_equal 1_000.to_d, breakdown.principal
  end

  test "rejects interest that consumes the whole payment" do
    assert_raises(ArgumentError) do
      Financial::Loans::PaymentBreakdown.new(total: 100, interest: 100)
    end
  end
end
