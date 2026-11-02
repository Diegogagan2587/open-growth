require "test_helper"

module Financial
  class CategoryBudgetsControllerTest < ActionDispatch::IntegrationTest
    setup do
      @user = users(:one)
      @account = accounts(:one)
      @category = categories(:one)
      @checking = Financial::Asset.create!(
        account: @account,
        name: "Budget test checking",
        account_type: "checking",
        status: "active",
        opening_balance: 1_000
      )
      @card = Financial::Liability.create!(
        account: @account,
        name: "Budget test card",
        liability_type: "credit_card",
        status: "active",
        opening_balance: 0
      )
      sign_in_as(@user, @account)
    end

    teardown do
      Current.account = nil
      Current.session = nil
    end

    test "shows category budget, actual spending, and remaining after a credit card payment" do
      period_start = Date.current.beginning_of_month
      period_end = Date.current.end_of_month
      Financial::CategoryBudget.create!(
        account: @account,
        category: @category,
        amount: 600,
        frequency: "monthly",
        starts_on: period_start
      )
      Financial::Entry.create!(
        account: @account,
        entry_type: "liability_payment",
        financial_account: @checking,
        financial_liability: @card,
        category: @category,
        entry_date: Date.current,
        amount: 600,
        description: "Payment to credit card"
      )
      Financial::Entry.create!(
        account: @account,
        entry_type: "liability_charge",
        financial_liability: @card,
        category: @category,
        entry_date: Date.current,
        amount: 241.57,
        description: "Gas charged to credit card"
      )

      get finance_category_budgets_path(period: "custom", start_date: period_start, end_date: period_end)

      assert_response :success
      assert_select "dt", text: "Budget limit"
      assert_select "dt", text: "Budget for selected period"
      assert_select "dt", text: "Actual spending"
      assert_select "dt", text: "Remaining budget"
      assert_includes response.body, "$600.00"
      assert_includes response.body, "$241.57"
      assert_includes response.body, "$358.43"
      assert_not_includes response.body, "$841.57"
      assert_includes response.body, "Transfers are excluded"
    end
  end
end
