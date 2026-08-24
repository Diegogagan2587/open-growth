require "test_helper"

class Financial::Loans::UpdateInstallmentDueDateTest < ActiveSupport::TestCase
  test "updates a pending planned due date only when selected" do
    account = Account.create!(name: "Due date tenant")
    category = Category.create!(account: account, name: "Loan payments")
    plan = Financial::Plan.create!(account: account, name: "Plan", planned_for: Date.new(2026, 9, 1), expected_amount: 100)
    loan = Financial::Loan.create!(account: account, name: "Loan", principal_amount: 100, lifecycle_status: "simulated")
    planned = Financial::PlannedTransaction.create!(account: account, plan: plan, category: category, description: "Installment", amount: 100, planned_for: Date.new(2026, 9, 15), due_date: Date.new(2026, 9, 15), kind: "liability_payment", importance: "essential", execution_status: "pending", status: "pending_to_pay")
    installment = Financial::Loan::Installment.create!(account: account, financial_loan: loan, installment_number: 1, due_date: Date.new(2026, 9, 15), expected_amount: 100, expected_principal: 100, expected_interest: 0, planned_transaction: planned)

    declined = Financial::Loans::UpdateInstallmentDueDate.call(installment: installment, due_date: Date.new(2026, 9, 20))
    assert declined.success?
    assert_equal Date.new(2026, 9, 15), planned.reload.due_date

    approved = Financial::Loans::UpdateInstallmentDueDate.call(installment: installment.reload, due_date: Date.new(2026, 9, 25), update_planned_transaction: true)
    assert approved.success?
    assert_equal Date.new(2026, 9, 25), planned.reload.due_date
    assert_equal Date.new(2026, 9, 25), planned.planned_for
  end

  test "updates a paid installment due date without changing applied history" do
    account = Account.create!(name: "Paid due date tenant")
    category = Category.create!(account: account, name: "Paid loan interest")
    liability = Financial::Liability.create!(account: account, name: "Paid loan debt", liability_type: "personal_credit", status: "active", opening_balance: 0)
    asset = Financial::Asset.create!(account: account, name: "Paid loan checking", account_type: "checking", status: "active", opening_balance: 1_000)
    plan = Financial::Plan.create!(account: account, name: "Paid loan plan", planned_for: Date.new(2026, 9, 1), expected_amount: 100)
    loan = Financial::Loan.create!(account: account, liability: liability, destination_asset: asset, interest_category: category, name: "Paid loan", principal_amount: 100, lifecycle_status: "active")
    planned = Financial::PlannedTransaction.create!(account: account, plan: plan, category: category, financial_account: asset, description: "Paid installment", amount: 100, planned_for: Date.new(2026, 9, 15), due_date: Date.new(2026, 9, 15), kind: "liability_payment", importance: "essential", execution_status: "pending", status: "pending_to_pay")
    installment = Financial::Loan::Installment.create!(account: account, financial_loan: loan, installment_number: 1, due_date: Date.new(2026, 9, 15), expected_amount: 100, expected_principal: 100, expected_interest: 0, planned_transaction: planned)

    payment = Financial::Loans::ApplyInstallmentPayment.call(installment: installment, total: 100, interest: 0, entry_date: Date.new(2026, 9, 10)).entry
    original_entry = payment.attributes.slice("entry_date", "amount", "description", "entry_type")
    original_planned = planned.reload.attributes.slice("execution_status", "status", "planned_for", "due_date", "applied_on")

    result = Financial::Loans::UpdateInstallmentDueDate.call(installment: installment.reload, due_date: Date.new(2026, 9, 20))

    assert result.success?
    assert_equal Date.new(2026, 9, 20), installment.reload.due_date
    assert installment.manual_due_date
    assert_equal "paid", installment.resolution
    assert_equal original_entry, payment.reload.attributes.slice("entry_date", "amount", "description", "entry_type")
    assert_equal original_planned, planned.reload.attributes.slice("execution_status", "status", "planned_for", "due_date", "applied_on")
  end

  test "rejects a stale due date correction" do
    account = Account.create!(name: "Stale due date tenant")
    loan = Financial::Loan.create!(account: account, name: "Stale loan", principal_amount: 300, lifecycle_status: "simulated")
    installment = Financial::Loan::Installment.create!(account: account, financial_loan: loan, installment_number: 1, due_date: Date.new(2026, 9, 15), expected_amount: 100, expected_principal: 100, expected_interest: 0)
    expected_updated_at = installment.reload.updated_at.iso8601(6)
    installment.update!(due_date: Date.new(2026, 9, 16))

    result = Financial::Loans::UpdateInstallmentDueDate.call(installment: installment.reload, due_date: Date.new(2026, 9, 20), expected_updated_at: expected_updated_at)

    assert_not result.success?
    assert_match(/changed since this form was opened|review the installment again/i, result.error_message)
    assert_equal Date.new(2026, 9, 16), installment.reload.due_date
  end

  test "rejects a due date that crosses a neighboring installment" do
    account = Account.create!(name: "Ordered due date tenant")
    loan = Financial::Loan.create!(account: account, name: "Ordered loan", principal_amount: 300, lifecycle_status: "simulated")
    first = Financial::Loan::Installment.create!(account: account, financial_loan: loan, installment_number: 1, due_date: Date.new(2026, 9, 15), expected_amount: 100, expected_principal: 100, expected_interest: 0)
    second = Financial::Loan::Installment.create!(account: account, financial_loan: loan, installment_number: 2, due_date: Date.new(2026, 10, 15), expected_amount: 100, expected_principal: 100, expected_interest: 0)

    result = Financial::Loans::UpdateInstallmentDueDate.call(installment: first, due_date: Date.new(2026, 10, 20))

    assert_not result.success?
    assert_match(/before installment #2/i, result.error_message)
    assert_equal Date.new(2026, 9, 15), first.reload.due_date
    assert_equal Date.new(2026, 10, 15), second.reload.due_date
  end
end
