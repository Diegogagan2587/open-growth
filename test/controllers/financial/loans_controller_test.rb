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
end
