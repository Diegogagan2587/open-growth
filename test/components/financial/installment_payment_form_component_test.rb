# frozen_string_literal: true

require "test_helper"

class Financial::InstallmentPaymentFormComponentTest < ViewComponent::TestCase
  test "renders the interest-aware payment resource for a loan installment" do
    account = accounts(:one)
    loan = Financial::Loan.create!(account: account, name: "Component loan", principal_amount: 100)
    plan = Financial::Plan.create!(account: account, name: "Component plan", planned_for: Date.current, expected_amount: 1)
    transaction = Financial::PlannedTransaction.create!(account: account, plan: plan, category: categories(:one), description: "Loan payment", amount: 60, kind: "liability_payment", status: "pending_to_pay")
    installment = Financial::Loan::Installment.create!(account: account, financial_loan: loan, planned_transaction: transaction, installment_number: 1, due_date: Date.current, expected_amount: 60, expected_principal: 50, expected_interest: 10)

    render_inline(Financial::InstallmentPaymentFormComponent.new(transaction: transaction))

    path = Rails.application.routes.url_helpers.finance_loan_installment_payment_path(loan, installment)
    assert_css "form[action='#{path}']"
    assert_css "input[name='installment_payment[interest]'][value='10.0']"
  end
end
