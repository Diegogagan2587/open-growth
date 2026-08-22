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

  test "cannot delete an asset referenced by an actual entry" do
    financial_account = Financial::Asset.create!(
      account: @account,
      name: "Protected Debit",
      account_type: "debit",
      status: "active",
      opening_balance: 0
    )
    entry = Financial::Entry.create!(
      account: @account,
      financial_account: financial_account,
      entry_type: "inflow",
      entry_date: Date.current,
      amount: 50,
      description: "Deposit"
    )

    assert_not financial_account.destroy
    assert Financial::Asset.exists?(financial_account.id)
    assert Financial::Entry.exists?(entry.id)
  end

  test "cannot delete a liability referenced by an actual entry" do
    liability = Financial::Liability.create!(
      account: @account,
      name: "Protected Card",
      liability_type: "credit_card",
      status: "active",
      opening_balance: 0
    )
    entry = Financial::Entry.create!(
      account: @account,
      financial_liability: liability,
      category: Category.first,
      entry_type: "liability_charge",
      entry_date: Date.current,
      amount: 50,
      description: "Purchase"
    )

    assert_not liability.destroy
    assert Financial::Liability.exists?(liability.id)
    assert Financial::Entry.exists?(entry.id)
  end

  test "stores assets and liabilities in the canonical account model" do
    asset = Financial::Account.create!(account: @account, name: "Checking", account_group: "asset", account_type: "checking", status: "active", opening_balance: 0)
    liability = Financial::Account.create!(account: @account, name: "Card", account_group: "liability", account_type: "credit_card", status: "active", opening_balance: 0)

    assert_predicate asset, :asset?
    assert_predicate liability, :liability?
    assert_equal [ asset ], @account.financial_accounts.assets.to_a
    assert_equal [ liability ], @account.financial_accounts.liabilities.to_a
  end
end
