require "test_helper"

class Financial::LoanTest < ActiveSupport::TestCase
  test "interest rate must be nonnegative" do
    loan = Financial::Loan.new(name: "Invalid rate", principal_amount: 1, interest_rate: -0.001)

    assert_not loan.valid?
    assert_includes loan.errors[:interest_rate], "must be greater than or equal to 0"
  end

  test "configures and exposes a different payment position" do
    loan = Financial::Loan.new(
      name: "Beginning payment",
      principal_amount: 1_000,
      lifecycle_status: "simulated"
    )
    terms = Financial::Loans::RepaymentTerms.new(
      principal: 1_000,
      number_of_payments: 3,
      payment_frequency: "monthly",
      repayment_basis: "payment_amounts",
      regular_payment: 400,
      different_payment_amount: 350,
      different_payment_position: "beginning"
    )

    loan.configure_repayment(terms)

    assert_equal "beginning", loan.different_payment_position
    assert_equal 350.to_d, loan.different_payment_amount
    assert_equal "beginning", loan.repayment_terms.different_payment_position
    assert_equal [ 350.to_d, 400.to_d, 400.to_d ], loan.repayment_terms.contractual_payments
  end

  test "simulation creates no debt and activation disburses only once" do
    account = Account.create!(name: "Loan Tenant")
    Current.account = account
    liability = Financial::Liability.create!(account: account, name: "Loan", liability_type: "personal_credit", status: "active", opening_balance: 0)
    asset = Financial::Asset.create!(account: account, name: "Checking", account_type: "checking", status: "active", opening_balance: 0)
    plan = Financial::Plan.create!(account: account, name: "Borrowing", planned_for: Date.current, expected_amount: 1)

    loan = Financial::Loan.create!(
      account: account,
      name: "Personal loan",
      principal_amount: 1_000,
      lifecycle_status: "simulated"
    )
    assert_equal 0, loan.entries.count

    loan.update!(liability: liability, destination_asset: asset)
    first = Financial::Loans::ActivateService.call(loan: loan, plan: plan)
    second = Financial::Loans::ActivateService.call(loan: loan.reload, plan: plan)

    assert first.success?
    assert second.success?
    assert_equal first.entry, second.entry
    assert_equal 1, loan.entries.where(entry_type: "loan_disbursement").count
    assert_equal 1_000.to_d, loan.actual_balance
    assert_equal 1_000.to_d, liability.current_balance
  ensure
    Current.account = nil
  end

  test "owns schedule regeneration and preserves manual dates" do
    account = Account.create!(name: "Regeneration domain tenant")
    loan = Financial::Loan.create!(
      account: account,
      name: "Regeneration loan",
      principal_amount: 2_000,
      repayment_basis: "payment_amounts",
      interest_rate: 129.781,
      number_of_payments: 2,
      payment_frequency: "monthly",
      payment_amount: 1_165,
      lifecycle_status: "simulated"
    )

    generated = loan.regenerate_schedule!(start_date: Date.new(2026, 8, 1))
    generated.first.update!(due_date: Date.new(2026, 9, 5), manual_due_date: true)

    regenerated = loan.regenerate_schedule!(start_date: Date.new(2026, 8, 1))

    assert_equal [ 1_165.to_d, 1_165.to_d ], regenerated.map(&:expected_amount)
    assert_equal Date.new(2026, 9, 5), regenerated.first.due_date
    assert regenerated.first.manual_due_date
  end
end
