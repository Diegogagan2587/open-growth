require "test_helper"

class Financial::Loans::InstallmentWorkflowTest < ActiveSupport::TestCase
  test "generates expected installments and pays one through a planned transaction" do
    account = Account.create!(name: "Installment Tenant")
    Current.account = account
    liability = Financial::Liability.create!(account: account, name: "Loan debt", liability_type: "personal_credit", status: "active", opening_balance: 0)
    asset = Financial::Asset.create!(account: account, name: "Checking", account_type: "checking", status: "active", opening_balance: 1_000)
    plan = Financial::Plan.create!(account: account, name: "Payment plan", planned_for: Date.new(2026, 8, 1), expected_amount: 1)
    loan = Financial::Loan.create!(
      account: account,
      liability: liability,
      destination_asset: asset,
      name: "Small loan",
      principal_amount: 1_000,
      interest_rate: 12,
      number_of_payments: 2,
      payment_frequency: "monthly",
      lifecycle_status: "simulated"
    )
    assert Financial::Loans::ActivateService.call(loan: loan, plan: plan).success?

    generated = Financial::Loans::GenerateInstallmentsService.call(loan: loan, start_date: Date.new(2026, 8, 1))
    assert generated.success?
    assert_equal 2, loan.installments.count

    installment = loan.installments.order(:installment_number).first
    planned = Financial::Loans::PlanInstallmentService.call(installment: installment, plan: plan, source_account: asset)
    assert planned.success?
    assert_equal "liability_payment", planned.planned_transaction.kind

    applied = Financial::PlannedTransactions::ApplyService.call(planned_transaction: planned.planned_transaction)
    assert applied.success?
    assert_equal applied.entry, installment.reload.payment_entry
    assert_equal "paid", installment.resolution
    assert_equal loan, applied.entry.financial_loan
  ensure
    Current.account = nil
  end
end
