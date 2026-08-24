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
      different_payment_amount: 350
    )

    assert_equal [ 400.to_d, 400.to_d, 350.to_d ], terms.contractual_payments
    assert_equal 1_150.to_d, terms.total_repayment
    assert terms.annual_rate.positive?
  end

  test "uses a different beginning payment in the inferred payment stream" do
    terms = Financial::Loans::RepaymentTerms.new(
      principal: 1_000,
      number_of_payments: 3,
      payment_frequency: "monthly",
      repayment_basis: "payment_amounts",
      regular_payment: 400,
      different_payment_amount: 350,
      different_payment_position: "beginning"
    )

    assert_equal [ 350.to_d, 400.to_d, 400.to_d ], terms.contractual_payments
  end

  test "defaults a different payment to the final position" do
    terms = Financial::Loans::RepaymentTerms.new(
      principal: 1_000,
      number_of_payments: 3,
      payment_frequency: "monthly",
      repayment_basis: "payment_amounts",
      regular_payment: 400,
      different_payment_amount: 350
    )

    assert_equal "final", terms.different_payment_position
    assert_equal [ 400.to_d, 400.to_d, 350.to_d ], terms.contractual_payments
  end

  test "uses a different payment only once for a one-payment schedule" do
    terms = Financial::Loans::RepaymentTerms.new(
      principal: 350,
      number_of_payments: 1,
      payment_frequency: "monthly",
      repayment_basis: "payment_amounts",
      regular_payment: 400,
      different_payment_amount: 350,
      different_payment_position: "beginning"
    )

    assert_equal [ 350.to_d ], terms.contractual_payments
  end

  test "rejects an unsupported different payment position" do
    error = assert_raises(ArgumentError) do
      Financial::Loans::RepaymentTerms.new(
        principal: 1_000,
        number_of_payments: 3,
        payment_frequency: "monthly",
        repayment_basis: "payment_amounts",
        regular_payment: 400,
        different_payment_amount: 350,
        different_payment_position: "middle"
      )
    end

    assert_equal "Different payment position is not supported", error.message
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
