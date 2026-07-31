require "test_helper"

class Reporting::AnalysisSnapshotTest < ActiveSupport::TestCase
  test "contains only entries from the requested account and period" do
    account = accounts(:one)
    other_account = accounts(:two)
    category = Category.create!(account:, name: "Snapshot category")
    asset = Financial::Asset.create!(account:, name: "Snapshot checking", account_type: "checking", status: "active", opening_balance: 0)
    included = Financial::Entry.create!(account:, category:, financial_account: asset, entry_type: "outflow", entry_date: Date.current, amount: 25, description: "Included")

    other_category = Category.create!(account: other_account, name: "Private category")
    other_asset = Financial::Asset.create!(account: other_account, name: "Private checking", account_type: "checking", status: "active", opening_balance: 0)
    excluded = Financial::Entry.create!(account: other_account, category: other_category, financial_account: other_asset, entry_type: "outflow", entry_date: Date.current, amount: 90, description: "Excluded")

    snapshot = Reporting::AnalysisSnapshot.new(account:, date_range: Date.current..Date.current).as_json
    ids = snapshot[:entries].pluck(:id)

    assert_includes ids, included.id
    refute_includes ids, excluded.id
    assert_equal 1, snapshot[:total_entry_count]
  end
end
