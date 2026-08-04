require "test_helper"

class Financial::LoansControllerTest < ActionDispatch::IntegrationTest
  setup do
    @user = users(:one)
    @account = accounts(:one)
    sign_in_as(@user, @account)
  end

  teardown do
    Current.account = nil
    Current.session = nil
  end

  test "creates and displays a simulated loan without creating an entry" do
    assert_difference("Financial::Loan.count", 1) do
      assert_no_difference("Financial::Entry.count") do
        post finance_loans_path, params: {
          financial_loan: {
            name: "Car simulation",
            principal_amount: "10000",
            interest_rate: "12",
            number_of_payments: "24",
            payment_frequency: "monthly"
          }
        }
      end
    end

    loan = Financial::Loan.order(:id).last
    assert_redirected_to finance_loan_path(loan)

    get finance_loans_path
    assert_response :success
    assert_select "a[href='#{finance_loan_path(loan)}']", text: /Car simulation/
  end

  test "creates a simulated loan with an annual interest rate above one thousand percent" do
    assert_difference("Financial::Loan.count", 1) do
      post finance_loans_path, params: {
        financial_loan: {
          name: "High-interest simulation",
          principal_amount: "2000",
          interest_rate: "1200",
          number_of_payments: "6",
          payment_frequency: "quincenal"
        }
      }
    end

    loan = Financial::Loan.order(:id).last
    assert_redirected_to finance_loan_path(loan)
    assert_equal 1200.to_d, loan.interest_rate
  end

  test "creates a simulated loan without an arbitrary interest rate ceiling" do
    assert_difference("Financial::Loan.count", 1) do
      post finance_loans_path, params: {
        financial_loan: {
          name: "Very high-interest simulation",
          principal_amount: "2000",
          interest_rate: "100000"
        }
      }
    end

    loan = Financial::Loan.order(:id).last
    assert_redirected_to finance_loan_path(loan)
    assert_equal 100_000.to_d, loan.interest_rate
  end

  test "loan edit form uses finance routes and updates the simulation" do
    loan = Financial::Loan.create!(account: @account, name: "Editable loan", principal_amount: 500, lifecycle_status: "simulated")

    get edit_finance_loan_path(loan)
    assert_response :success
    assert_select "form[action='#{finance_loan_path(loan)}']" do
      assert_select "input[name='_method'][value='patch']"
    end

    patch finance_loan_path(loan), params: {
      financial_loan: { name: "Updated loan", principal_amount: "500" }
    }

    assert_redirected_to finance_loan_path(loan)
    assert_equal "Updated loan", loan.reload.name
  end

  test "creates exact-payment terms and infers the annual rate" do
    post finance_loans_path, params: {
      financial_loan: {
        name: "Known payments",
        principal_amount: "2000",
        repayment_basis: "payment_amounts",
        number_of_payments: "2",
        payment_frequency: "monthly",
        payment_amount: "1165"
      }
    }

    loan = Financial::Loan.order(:id).last
    assert_redirected_to finance_loan_path(loan)
    assert_equal "payment_amounts", loan.repayment_basis
    assert loan.interest_rate_estimated?
    assert_equal 129.781.to_d, loan.interest_rate
  end

  test "creates a schedule through the nested schedule resource" do
    loan = Financial::Loan.create!(
      account: @account,
      name: "Scheduled loan",
      principal_amount: 2_000,
      repayment_basis: "payment_amounts",
      interest_rate: 129.781,
      number_of_payments: 2,
      payment_frequency: "monthly",
      payment_amount: 1_165
    )

    post finance_loan_schedule_path(loan), params: { start_date: "2026-08-01" }

    assert_redirected_to finance_loan_path(loan)
    assert_equal [ 1_165.to_d, 1_165.to_d ], loan.installments.order(:installment_number).pluck(:expected_amount)
  end

  test "records a categorized installment payment through the nested payment resource" do
    interest_category = Category.create!(account: @account, name: "Loan interest request")
    liability = Financial::Liability.create!(account: @account, name: "Request loan", liability_type: "personal_credit", status: "active", opening_balance: 2_000)
    asset = Financial::Asset.create!(account: @account, name: "Request checking", account_type: "checking", status: "active", opening_balance: 2_000)
    plan = Financial::Plan.create!(account: @account, name: "Request payment plan", planned_for: Date.current, expected_amount: 1)
    loan = Financial::Loan.create!(account: @account, name: "Request loan", principal_amount: 2_000, liability: liability, destination_asset: asset, interest_category: interest_category, lifecycle_status: "active")
    transaction = Financial::PlannedTransaction.create!(account: @account, plan: plan, description: "Request installment", amount: 1_165, kind: "liability_payment", status: "pending_to_pay", financial_account: asset, financial_liability: liability)
    installment = Financial::LoanInstallment.create!(account: @account, financial_loan: loan, planned_transaction: transaction, installment_number: 1, due_date: Date.current, expected_amount: 1_165, expected_principal: 1_000, expected_interest: 165)

    post finance_loan_installment_payment_path(loan, installment), params: {
      installment_payment: { total: "1165", interest: "165", entry_date: Date.current }
    }

    assert_redirected_to finance_loan_path(loan)
    assert_equal "paid", installment.reload.resolution
    assert_equal 165.to_d, installment.interest_entry.amount
    assert_equal 1_165.to_d, installment.payment_entry.amount
  end
end
