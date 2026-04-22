require "test_helper"

class Loans::ScheduleGeneratorTest < ActiveSupport::TestCase
  def setup
    @account = Account.create!(name: "Test Account")
    Current.account = @account

    @budget_period = BudgetPeriod.create!(
      name: "Test Period",
      start_date: Date.new(2025, 1, 1),
      end_date: Date.new(2025, 12, 31),
      account: @account
    )
  end

  def teardown
    Current.account = nil
  end

  test "generates a monthly repayment schedule" do
    loan = IncomeEvent.create!(
      budget_period: @budget_period,
      description: "Car Loan",
      expected_date: Date.new(2025, 1, 15),
      income_type: "loan",
      loan_amount: 1200.00,
      interest_rate: 0.0,
      number_of_payments: 3,
      payment_frequency: "monthly",
      status: "pending",
      account: @account
    )

    schedules = loan.generate_loan_payment_schedules!

    assert_equal 3, schedules.size
    assert_equal 3, loan.loan_payment_schedules.count
    assert_equal Date.new(2025, 2, 15), schedules.first.due_date
    assert_equal 400.0, schedules.first.amount.to_f
    assert_equal 1200.0, loan.loan_total_repayment.to_f
  end

  test "regenerates future rows while preserving paid rows" do
    loan = IncomeEvent.create!(
      budget_period: @budget_period,
      description: "Refi Loan",
      expected_date: Date.new(2025, 1, 15),
      income_type: "loan",
      loan_amount: 900.00,
      interest_rate: 0.0,
      number_of_payments: 3,
      payment_frequency: "monthly",
      status: "pending",
      account: @account
    )

    loan.generate_loan_payment_schedules!
    first_schedule = loan.loan_payment_schedules.ordered.first
    first_schedule.mark_paid!

    loan.update!(number_of_payments: 4)
    loan.reload

    assert_equal 4, loan.loan_payment_schedules.count
    assert_equal "paid", loan.loan_payment_schedules.ordered.first.status
  end

  test "fixed payment mode respects requested installment count" do
    loan = IncomeEvent.create!(
      budget_period: @budget_period,
      description: "MexDin Loan",
      expected_date: Date.new(2025, 1, 15),
      income_type: "loan",
      loan_amount: 200.00,
      interest_rate: nil,
      number_of_payments: 6,
      payment_frequency: "biweekly",
      payment_amount: 58.83,
      status: "pending",
      account: @account
    )

    schedules = loan.generate_loan_payment_schedules!

    assert_equal 6, schedules.size
    assert_equal 6, loan.loan_payment_schedules.count
  end

  test "quincenal schedules advance every 15 days" do
    loan = IncomeEvent.create!(
      budget_period: @budget_period,
      description: "Quincenal Loan",
      expected_date: Date.new(2025, 1, 1),
      income_type: "loan",
      loan_amount: 1000.00,
      interest_rate: 0.0,
      number_of_payments: 3,
      payment_frequency: "quincenal",
      status: "pending",
      account: @account
    )

    schedules = loan.generate_loan_payment_schedules!

    assert_equal Date.new(2025, 1, 16), schedules.first.due_date
    assert_equal Date.new(2025, 1, 31), schedules.second.due_date
    assert_equal Date.new(2025, 2, 15), schedules.third.due_date
  end
end
