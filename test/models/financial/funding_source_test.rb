require "test_helper"

class Financial::FundingSourceTest < ActiveSupport::TestCase
  def setup
    @account = Account.create!(name: "Funding Tenant")
    Current.account = @account
    @asset = Financial::Asset.create!(
      account: @account,
      name: "Checking",
      account_type: "checking",
      status: "active",
      opening_balance: 0
    )
    @plan = Financial::Plan.create!(
      account: @account,
      name: "July plan",
      planned_for: Date.current,
      expected_amount: 1
    )
  end

  def teardown
    Current.account = nil
  end

  test "reads actual values from its receipt entry" do
    source = Financial::FundingSource.create!(
      account: @account,
      financial_plan: @plan,
      description: "Salary",
      expected_amount: 100,
      expected_date: Date.current,
      expected_destination_asset: @asset,
      kind: "income"
    )
    entry = Financial::Entry.create!(
      account: @account,
      funding_source: source,
      financial_account: @asset,
      entry_type: "inflow",
      entry_date: Date.current + 1,
      amount: 95,
      description: "Salary"
    )

    assert_equal 95.to_d, source.actual_amount
    assert_equal Date.current + 1, source.actual_date
    assert_equal entry, source.receipt_entry
  end

  test "rejects a plan or destination from another account" do
    other_account = Account.create!(name: "Other Funding Tenant")
    other_asset = Financial::Asset.create!(
      account: other_account,
      name: "Other Checking",
      account_type: "checking",
      status: "active",
      opening_balance: 0
    )
    source = Financial::FundingSource.new(
      account: @account,
      financial_plan: @plan,
      description: "Invalid",
      expected_amount: 100,
      expected_date: Date.current,
      expected_destination_asset: other_asset
    )

    assert_not source.valid?
    assert_includes source.errors[:expected_destination_asset], "must belong to the current account"
  end
end
