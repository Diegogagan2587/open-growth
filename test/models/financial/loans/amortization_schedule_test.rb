require "test_helper"

class Financial::Loans::AmortizationScheduleTest < ActiveSupport::TestCase
  test "preserves exact fixed payments and closes principal" do
    terms = Financial::Loans::RepaymentTerms.new(
      principal: 2_000,
      number_of_payments: 2,
      payment_frequency: "monthly",
      repayment_basis: "payment_amounts",
      regular_payment: 1_165
    )

    schedule = Financial::Loans::AmortizationSchedule.build(terms: terms, start_date: Date.new(2026, 8, 1))

    assert_equal [ 1_165.to_d, 1_165.to_d ], schedule.map(&:amount)
    assert_equal 2_000.to_d, schedule.sum(&:principal)
    assert_equal 330.to_d, schedule.sum(&:interest)
    assert_operator schedule.first.interest, :>, schedule.last.interest
    assert_equal [ Date.new(2026, 9, 1), Date.new(2026, 10, 1) ], schedule.map(&:due_date)
  end

  test "rate-based schedule adjusts the final payment only for rounding" do
    terms = Financial::Loans::RepaymentTerms.new(
      principal: 1_000,
      number_of_payments: 3,
      payment_frequency: "monthly",
      repayment_basis: "annual_rate",
      annual_rate: 12
    )

    schedule = Financial::Loans::AmortizationSchedule.build(terms: terms, start_date: Date.new(2026, 8, 1))

    assert_equal schedule.first.amount, schedule.second.amount
    assert_equal 1_000.to_d, schedule.sum(&:principal)
  end
end
