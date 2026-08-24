require "test_helper"

class Financial::Loans::RepaymentWorkflowsTest < ActiveSupport::TestCase
  setup do
    @account = Account.create!(name: "Repayment domain tenant")
    Current.account = @account
    @interest_category = Category.create!(account: @account, name: "Commissions and Interest")
    @liability = Financial::Liability.create!(account: @account, name: "Loan debt", liability_type: "personal_credit", status: "active", opening_balance: 0)
    @asset = Financial::Asset.create!(account: @account, name: "Checking", account_type: "checking", status: "active", opening_balance: 3_000)
    @plan = Financial::Plan.create!(account: @account, name: "Repayment plan", planned_for: Date.new(2026, 9, 1), expected_amount: 1)
    @loan = Financial::Loan.create!(
      account: @account,
      liability: @liability,
      destination_asset: @asset,
      interest_category: @interest_category,
      name: "Two-payment loan",
      principal_amount: 2_000,
      repayment_basis: "payment_amounts",
      interest_rate: 129.781,
      number_of_payments: 2,
      payment_frequency: "monthly",
      payment_amount: 1_165,
      lifecycle_status: "simulated"
    )
    Financial::Loans::ActivateService.call(loan: @loan, plan: @plan)
  end

  teardown do
    Current.account = nil
  end

  test "regenerates exact payments and synchronizes a pending plan" do
    first = Financial::Loans::RegenerateSchedule.call(loan: @loan, start_date: Date.new(2026, 8, 1))
    installment = first.installments.first
    Financial::Loans::PlanInstallmentService.call(installment: installment, plan: @plan, source_account: @asset)

    @loan.configure_repayment(Financial::Loans::RepaymentTerms.new(
      principal: 2_000,
      number_of_payments: 2,
      payment_frequency: "monthly",
      repayment_basis: "payment_amounts",
      regular_payment: 1_175
    )).save!
    regenerated = Financial::Loans::RegenerateSchedule.call(loan: @loan, start_date: Date.new(2026, 8, 1))

    assert regenerated.success?
    assert_equal [ 1_175.to_d, 1_175.to_d ], @loan.installments.order(:installment_number).pluck(:expected_amount)
    assert_equal 1_165.to_d, installment.planned_transaction.reload.amount
    assert_equal Date.new(2026, 9, 1), installment.planned_transaction.planned_for
  end

  test "regenerates a changed different payment position" do
    Financial::Loans::RegenerateSchedule.call(loan: @loan, start_date: Date.new(2026, 8, 1))
    @loan.configure_repayment(Financial::Loans::RepaymentTerms.new(
      principal: 2_000,
      number_of_payments: 2,
      payment_frequency: "monthly",
      repayment_basis: "payment_amounts",
      regular_payment: 1_165,
      different_payment_amount: 1_000,
      different_payment_position: "beginning"
    )).save!

    regenerated = Financial::Loans::RegenerateSchedule.call(loan: @loan, start_date: Date.new(2026, 8, 1))

    assert regenerated.success?
    assert_equal [ 1_000.to_d, 1_165.to_d ], @loan.installments.order(:installment_number).pluck(:expected_amount)
  end

  test "records interest as an expense charge and the full liability payment once" do
    generated = Financial::Loans::RegenerateSchedule.call(loan: @loan, start_date: Date.new(2026, 8, 1))
    installment = generated.installments.first
    Financial::Loans::PlanInstallmentService.call(installment: installment, plan: @plan, source_account: @asset)

    first = Financial::Loans::ApplyInstallmentPayment.call(
      installment: installment,
      total: 1_165,
      interest: 165,
      entry_date: Date.new(2026, 9, 1)
    )
    second = Financial::Loans::ApplyInstallmentPayment.call(
      installment: installment.reload,
      total: 1_165,
      interest: 165,
      entry_date: Date.new(2026, 9, 1)
    )

    assert first.success?
    assert second.success?
    assert_equal first.entry, second.entry
    assert_equal 1, @loan.entries.where(entry_type: "liability_charge").count
    assert_equal 1, @loan.entries.where(entry_type: "liability_payment").count
    assert_equal 165.to_d, installment.reload.interest_entry.amount
    assert_equal @interest_category, installment.interest_entry.category
    assert_equal 1_000.to_d, @loan.actual_balance
    assert_equal 165.to_d, Financial::Entry.where(category: @interest_category, entry_type: "liability_charge").sum(:amount)
  end

  test "requires an interest category without leaving partial ledger entries" do
    @loan.update!(interest_category: nil)
    installment = Financial::Loans::RegenerateSchedule.call(loan: @loan, start_date: Date.new(2026, 8, 1)).installments.first
    Financial::Loans::PlanInstallmentService.call(installment: installment, plan: @plan, source_account: @asset)

    assert_no_difference("Financial::Entry.count") do
      result = Financial::Loans::ApplyInstallmentPayment.call(installment: installment, total: 1_165, interest: 165, entry_date: Date.current)
      assert_not result.success?
      assert_equal "Select an interest category on the loan", result.error_message
    end
  end
end
