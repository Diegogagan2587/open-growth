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

  test "loan form exposes the different payment position selector" do
    loan = Financial::Loan.create!(account: @account, name: "Position form loan", principal_amount: 500, lifecycle_status: "simulated")

    get edit_finance_loan_path(loan)

    assert_response :success
    assert_select "select[name='financial_loan[different_payment_position]']" do
      assert_select "option[value='beginning']", text: "Beginning"
      assert_select "option[value='final']", text: "Final", selected: true
    end
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

  test "creates exact-payment terms with a beginning different payment" do
    post finance_loans_path, params: {
      financial_loan: {
        name: "Beginning payment loan",
        principal_amount: "1000",
        repayment_basis: "payment_amounts",
        number_of_payments: "3",
        payment_frequency: "monthly",
        payment_amount: "400",
        different_payment_amount: "350",
        different_payment_position: "beginning"
      }
    }

    loan = Financial::Loan.order(:id).last
    assert_redirected_to finance_loan_path(loan)
    assert_equal "beginning", loan.different_payment_position
    assert_equal 350.to_d, loan.different_payment_amount
  end

  test "explains the minimum beginning payment when the configured amount is invalid" do
    post finance_loans_path, params: {
      financial_loan: {
        name: "Invalid beginning payment loan",
        principal_amount: "5000",
        repayment_basis: "payment_amounts",
        number_of_payments: "6",
        payment_frequency: "monthly",
        payment_amount: "1311",
        different_payment_amount: "50",
        different_payment_position: "beginning"
      }
    }

    assert_response :unprocessable_entity
    assert_select "p", text: /Installment 1 payment of 50.*estimated accrued interest.*enter at least/
  end

  test "shows an actionable schedule alert for a legacy invalid payment stream" do
    loan = Financial::Loan.create!(account: @account, name: "Legacy invalid loan", principal_amount: 5_000, repayment_basis: "payment_amounts", number_of_payments: 6, payment_frequency: "monthly", payment_amount: 1_311, lifecycle_status: "simulated")
    loan.update_columns(different_payment_amount: 50, different_payment_position: "beginning")

    post finance_loan_schedule_path(loan), params: { first_payment_date: "2026-09-15" }

    assert_redirected_to finance_loan_path(loan)
    assert_match(/Installment 1 payment of 50.*estimated accrued interest.*enter at least/, flash[:alert])
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

  test "creates a schedule with a different beginning payment" do
    loan = Financial::Loan.create!(
      account: @account,
      name: "Beginning scheduled loan",
      principal_amount: 1_000,
      repayment_basis: "payment_amounts",
      interest_rate: 0,
      number_of_payments: 3,
      payment_frequency: "monthly",
      payment_amount: 400,
      different_payment_amount: 350,
      different_payment_position: "beginning"
    )

    post finance_loan_schedule_path(loan), params: { start_date: "2026-08-01" }

    assert_redirected_to finance_loan_path(loan)
    assert_equal [ 350.to_d, 400.to_d, 400.to_d ], loan.installments.order(:installment_number).pluck(:expected_amount)
  end

  test "shows the different payment position on the loan page" do
    loan = Financial::Loan.create!(
      account: @account,
      name: "Position display loan",
      principal_amount: 1_000,
      repayment_basis: "payment_amounts",
      interest_rate: 0,
      number_of_payments: 3,
      payment_frequency: "monthly",
      payment_amount: 400,
      different_payment_amount: 350,
      different_payment_position: "beginning"
    )

    get finance_loan_path(loan)

    assert_response :success
    assert_select "body", text: /Different payment: \$350\.00 at the beginning position/
  end

  test "records a categorized installment payment through the nested payment resource" do
    interest_category = Category.create!(account: @account, name: "Loan interest request")
    liability = Financial::Liability.create!(account: @account, name: "Request loan", liability_type: "personal_credit", status: "active", opening_balance: 2_000)
    asset = Financial::Asset.create!(account: @account, name: "Request checking", account_type: "checking", status: "active", opening_balance: 2_000)
    plan = Financial::Plan.create!(account: @account, name: "Request payment plan", planned_for: Date.current, expected_amount: 1)
    loan = Financial::Loan.create!(account: @account, name: "Request loan", principal_amount: 2_000, liability: liability, destination_asset: asset, interest_category: interest_category, lifecycle_status: "active")
    transaction = Financial::PlannedTransaction.create!(account: @account, plan: plan, description: "Request installment", amount: 1_165, kind: "liability_payment", status: "pending_to_pay", financial_account: asset, financial_liability: liability)
    installment = Financial::Loan::Installment.create!(account: @account, financial_loan: loan, planned_transaction: transaction, installment_number: 1, due_date: Date.current, expected_amount: 1_165, expected_principal: 1_000, expected_interest: 165)

    post finance_loan_installment_payment_path(loan, installment), params: {
      installment_payment: { total: "1165", interest: "165", entry_date: Date.current }
    }

    assert_redirected_to finance_loan_path(loan)
    assert_equal "paid", installment.reload.resolution
    assert_equal 165.to_d, installment.interest_entry.amount
    assert_equal 1_165.to_d, installment.payment_entry.amount
  end

  test "allows correcting a paid contractual due date while preserving the actual payment" do
    category = Category.create!(account: @account, name: "Paid correction category")
    liability = Financial::Liability.create!(account: @account, name: "Paid correction loan", liability_type: "personal_credit", status: "active", opening_balance: 0)
    asset = Financial::Asset.create!(account: @account, name: "Paid correction checking", account_type: "checking", status: "active", opening_balance: 1_000)
    plan = Financial::Plan.create!(account: @account, name: "Paid correction plan", planned_for: Date.new(2026, 9, 1), expected_amount: 100)
    loan = Financial::Loan.create!(account: @account, liability: liability, destination_asset: asset, name: "Paid correction loan", principal_amount: 100, lifecycle_status: "active")
    planned = Financial::PlannedTransaction.create!(account: @account, plan: plan, category: category, financial_account: asset, description: "Paid correction installment", amount: 100, planned_for: Date.new(2026, 9, 15), due_date: Date.new(2026, 9, 15), kind: "liability_payment", importance: "essential", execution_status: "pending", status: "pending_to_pay")
    installment = Financial::Loan::Installment.create!(account: @account, financial_loan: loan, installment_number: 1, due_date: Date.new(2026, 9, 15), expected_amount: 100, expected_principal: 100, expected_interest: 0, planned_transaction: planned)
    payment = Financial::Loans::ApplyInstallmentPayment.call(installment: installment, total: 100, interest: 0, entry_date: Date.new(2026, 9, 10)).entry

    get finance_loan_path(loan)

    assert_response :success
    assert_select "form[action='#{finance_loan_installment_path(loan, installment)}']"
    assert_select "input[name='installment[due_date]'][value='2026-09-15']"
    assert_select "form[data-turbo-confirm*='impact summary']"
    assert_select "body", text: /Paid installment: this changes only the contractual due date.*actual payment\/application date \(2026-09-10\).*accounting history remain unchanged/

    patch finance_loan_installment_path(loan, installment), params: {
      installment: { due_date: "2026-09-20" }
    }

    assert_redirected_to finance_loan_path(loan)
    assert_equal "Installment due date updated", flash[:notice]
    assert_equal Date.new(2026, 9, 20), installment.reload.due_date
    assert_equal Date.new(2026, 9, 10), payment.reload.entry_date
    assert_equal 100.to_d, payment.amount
    assert_equal "applied", planned.reload.execution_status
    assert_equal Date.new(2026, 9, 15), planned.due_date
  end
end
