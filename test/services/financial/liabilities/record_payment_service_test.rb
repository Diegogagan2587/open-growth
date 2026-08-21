require "test_helper"

class Financial::Liabilities::RecordPaymentServiceTest < ActiveSupport::TestCase
  def setup
    @account = Account.create!(name: "Tenant")
    Current.account = @account
    @category = Category.create!(account: @account, name: "Payments")

    @source_account = Financial::Asset.create!(
      account: @account,
      name: "Checking",
      account_type: "debit",
      status: "active",
      opening_balance: 1000
    )

    @liability = Financial::Liability.create!(
      account: @account,
      name: "Main Card",
      liability_type: "credit_card",
      status: "active",
      opening_balance: 0
    )

    Financial::Entry.create!(
      account: @account,
      financial_liability: @liability,
      entry_type: "liability_charge",
      entry_date: Date.current,
      amount: 50,
      description: "Initial charge",
      category: @category
    )
  end

  def teardown
    Current.account = nil
  end

  test "creates liability payment entry and reduces balance" do
    result = Financial::Liabilities::RecordPaymentService.call(
      liability: @liability,
      source_account: @source_account,
      amount: 20,
      description: "Payment",
      entry_date: Date.current
    )

    assert result.success?
    assert_equal 30.to_d, @liability.reload.current_balance
  end

  test "rejects payment above outstanding balance" do
    result = Financial::Liabilities::RecordPaymentService.call(
      liability: @liability,
      source_account: @source_account,
      amount: 80,
      description: "Too much",
      entry_date: Date.current
    )

    assert_not result.success?
    assert_equal "Payment amount cannot exceed outstanding liability", result.error_message
  end
end
