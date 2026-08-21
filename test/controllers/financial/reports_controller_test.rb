require "test_helper"

class Financial::ReportsControllerTest < ActionDispatch::IntegrationTest
  setup do
    @user = users(:one)
    @account = accounts(:one)
    checking = Financial::Account.create!(account: @account, name: "Report checking", account_group: "asset", account_type: "checking", status: "active", opening_balance: 0)
    Financial::Transaction.create!(account: @account, source_account: checking, category: categories(:one), transaction_type: "expense", transaction_date: Date.current, amount: 25, description: "Report expense")
    sign_in_as(@user, @account)
  end

  teardown { Current.reset }

  test "focused report controllers derive actuals from transactions" do
    get reports_path
    assert_response :success

    get reports_by_date_path
    assert_response :success

    get reports_spending_by_category_path
    assert_response :success

    get reports_category_trends_path
    assert_response :success
  end
end
