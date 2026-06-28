require "test_helper"

class Financial::AssetTest < ActiveSupport::TestCase
  def setup
    @account = Account.create!(name: "Tenant Account")
    Current.account = @account
  end

  def teardown
    Current.account = nil
  end

  test "calculates current balance from opening balance and entries" do
    financial_account = Financial::Asset.create!(
      account: @account,
      name: "Main Debit",
      account_type: "debit",
      status: "active",
      opening_balance: 100
    )

    Financial::Entry.create!(
      account: @account,
      financial_account: financial_account,
      entry_type: "inflow",
      entry_date: Date.current,
      amount: 50,
      description: "Deposit"
    )

    Financial::Entry.create!(
      account: @account,
      financial_account: financial_account,
      entry_type: "outflow",
      entry_date: Date.current,
      amount: 20,
      description: "Purchase",
      category: Category.first
    )

    assert_equal 130.to_d, financial_account.current_balance
  end
end
