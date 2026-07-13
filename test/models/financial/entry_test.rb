require "test_helper"

class Financial::EntryTest < ActiveSupport::TestCase
  def setup
    @account = Account.create!(name: "Tenant Account")
    Current.account = @account
    @financial_account = Financial::Asset.create!(
      account: @account,
      name: "Main Debit",
      account_type: "debit",
      status: "active",
      opening_balance: 0
    )
  end

  def teardown
    Current.account = nil
  end

  test "transfer requires destination account" do
    entry = Financial::Entry.new(
      account: @account,
      financial_account: @financial_account,
      entry_type: "transfer",
      entry_date: Date.current,
      amount: 10,
      description: "Move"
    )

    assert_not entry.valid?
    assert_includes entry.errors[:counterparty_financial_account], "must be selected"
  end

  test "liability payment requires liability and account" do
    entry = Financial::Entry.new(
      account: @account,
      entry_type: "liability_payment",
      entry_date: Date.current,
      amount: 20,
      description: "Card payment"
    )

    assert_not entry.valid?
    assert_includes entry.errors[:financial_account], "must be selected"
    assert_includes entry.errors[:financial_liability], "must be selected"
  end

  test "loan disbursement requires origin and one destination" do
    entry = Financial::Entry.new(
      account: @account,
      entry_type: "loan_disbursement",
      entry_date: Date.current,
      amount: 50,
      description: "Loan move"
    )

    assert_not entry.valid?
    assert_includes entry.errors[:financial_liability], "must be selected"
    assert_includes entry.errors[:base], "loan disbursement requires an asset or liability destination"
  end

  test "net asset effect excludes transfers and liability-only entries" do
    transfer = Financial::Entry.new(entry_type: "transfer", amount: 25, financial_account: @financial_account)
    charge = Financial::Entry.new(entry_type: "liability_charge", amount: 25)
    inflow = Financial::Entry.new(entry_type: "inflow", amount: 25, financial_account: @financial_account)
    outflow = Financial::Entry.new(entry_type: "outflow", amount: 25, financial_account: @financial_account)

    assert_equal 0.to_d, transfer.net_asset_effect
    assert_equal 0.to_d, charge.net_asset_effect
    assert_equal 25.to_d, inflow.net_asset_effect
    assert_equal(-25.to_d, outflow.net_asset_effect)
  end

  test "net liability effect includes both sides of liability movement" do
    liability = Financial::Liability.create!(
      account: @account,
      name: "Source card",
      liability_type: "credit_card",
      status: "active",
      opening_balance: 0
    )
    destination = Financial::Liability.create!(
      account: @account,
      name: "Destination card",
      liability_type: "credit_card",
      status: "active",
      opening_balance: 0
    )
    disbursement = Financial::Entry.new(
      entry_type: "loan_disbursement",
      amount: 25,
      financial_liability: liability,
      counterparty_financial_liability: destination
    )

    assert_equal 0.to_d, disbursement.net_liability_effect
  end
end
