require "test_helper"

class Financial::Loans::RepaymentTermsTest < ActiveSupport::TestCase
  test "infers an estimated annual rate from exact payment amounts" do
    terms = Financial::Loans::RepaymentTerms.new(
      principal: 2_000,
      number_of_payments: 2,
      payment_frequency: "monthly",
      repayment_basis: "payment_amounts",
      regular_payment: 1_165
    )

    assert terms.interest_rate_estimated?
    assert_equal 129.781.to_d, terms.annual_rate
    assert_equal [ 1_165.to_d, 1_165.to_d ], terms.contractual_payments
    assert_equal 2_330.to_d, terms.total_repayment
  end

  test "uses a different final payment in the inferred payment stream" do
    terms = Financial::Loans::RepaymentTerms.new(
      principal: 1_000,
      number_of_payments: 3,
      payment_frequency: "monthly",
      repayment_basis: "payment_amounts",
      regular_payment: 400,
      final_payment: 350
    )

    assert_equal [ 400.to_d, 400.to_d, 350.to_d ], terms.contractual_payments
    assert_equal 1_150.to_d, terms.total_repayment
    assert terms.annual_rate.positive?
  end

  test "rejects a payment stream that cannot repay principal" do
    error = assert_raises(ArgumentError) do
      Financial::Loans::RepaymentTerms.new(
        principal: 2_000,
        number_of_payments: 2,
        payment_frequency: "monthly",
        repayment_basis: "payment_amounts",
        regular_payment: 900
      )
    end

    assert_equal "Payment amounts do not repay the principal", error.message
  end
end
