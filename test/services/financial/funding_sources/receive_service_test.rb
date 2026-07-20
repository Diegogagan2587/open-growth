require "test_helper"

class Financial::FundingSources::ReceiveServiceTest < ActiveSupport::TestCase
  test "creates one actual receipt without changing the expectation" do
    account = Account.create!(name: "Receipt Tenant")
    Current.account = account
    asset = Financial::Asset.create!(
      account: account,
      name: "Checking",
      account_type: "checking",
      status: "active",
      opening_balance: 0
    )
    plan = Financial::Plan.create!(
      account: account,
      name: "July plan",
      planned_for: Date.current,
      expected_amount: 1
    )
    source = Financial::FundingSource.create!(
      account: account,
      financial_plan: plan,
      description: "Salary",
      expected_amount: 100,
      expected_date: Date.current,
      expected_destination_asset: asset,
      kind: "income"
    )

    first = Financial::FundingSources::ReceiveService.call(
      funding_source: source,
      amount: 95,
      entry_date: Date.current + 1
    )
    second = Financial::FundingSources::ReceiveService.call(
      funding_source: source,
      amount: 95,
      entry_date: Date.current + 1
    )

    assert first.success?
    assert second.success?
    assert_equal first.entry, second.entry
    assert_equal 1, Financial::Entry.where(funding_source: source).count
    assert_equal 100.to_d, source.reload.expected_amount
    assert_equal "closed_with_variance", source.resolution

    source.update!(resolution: "cancelled")
    assert Financial::Entry.exists?(first.entry.id)
  ensure
    Current.account = nil
  end
end
