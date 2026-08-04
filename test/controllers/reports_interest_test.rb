require "test_helper"

class ReportsInterestTest < ActionDispatch::IntegrationTest
  setup do
    @user = users(:one)
    @account = accounts(:one)
    sign_in_as(@user, @account)
  end

  teardown do
    Current.account = nil
    Current.session = nil
  end

  test "shows loan interest charges in spending by category" do
    category = Category.create!(account: @account, name: "Reported loan interest")
    liability = Financial::Liability.create!(account: @account, name: "Reported debt", liability_type: "personal_credit", status: "active", opening_balance: 0)
    Financial::Entry.create!(account: @account, category: category, financial_liability: liability, entry_type: "liability_charge", entry_date: Date.current, amount: 165, description: "Loan interest")

    get reports_spending_by_category_path(from: Date.current, to: Date.current, period: "none")

    assert_response :success
    assert_select "td", text: "Reported loan interest"
    assert_select "td", text: /165\.00/
  end
end
