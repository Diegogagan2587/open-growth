require "application_system_test_case"

class FinancialPlanExecutionTest < ApplicationSystemTestCase
  setup do
    @user = users(:one)
    @account = accounts(:one)
    category = categories(:one)
    asset = Financial::Asset.create!(account: @account, name: "System checking", account_type: "checking", status: "active", opening_balance: 500)
    @plan = Financial::Plan.create!(account: @account, name: "System execution", planned_for: Date.current, expected_amount: 1)
    Financial::PlannedTransaction.create!(account: @account, plan: @plan, category:, financial_account: asset, description: "First payment", amount: 25, due_date: Date.current, status: "pending_to_pay")
    Financial::PlannedTransaction.create!(account: @account, plan: @plan, category:, financial_account: asset, description: "Second payment", amount: 25, due_date: Date.current + 1, status: "pending_to_pay")
  end

  test "reorders planned movements and switches sort views" do
    visit new_session_path
    fill_in "email_address", with: @user.email_address
    fill_in "password", with: "password"
    click_button I18n.t("sessions.submit")
    assert_no_field "email_address"
    visit finance_plan_path(@plan, order: "custom")
    within "section[aria-labelledby='planned-transactions-title'] tbody" do
      all("tr").last.find("button[aria-label='Move Second payment up']").click
    end

    assert_text "Payment priority updated"
    assert_current_path finance_plan_path(@plan, order: "custom")
    within "section[aria-labelledby='planned-transactions-title'] tbody" do
      assert_text "Second payment"
      assert_includes all("tr").first.text, "Second payment"
    end

    click_link "Due-date order"
    assert_current_path finance_plan_path(@plan, order: "due_date")
    assert_selector "section[aria-labelledby='planned-transactions-title'] tbody tr:first-child", text: "First payment"
  end
end
