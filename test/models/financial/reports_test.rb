require "test_helper"

class Financial::ReportsTest < ActiveSupport::TestCase
  setup do
    @account = Account.create!(name: "Reporting household")
    @category = Category.create!(account: @account, name: "Food")
    checking = Financial::Account.create!(account: @account, name: "Checking", account_group: "asset", account_type: "checking", status: "active", opening_balance: 0)
    Financial::Transaction.create!(account: @account, source_account: checking, category: @category, transaction_type: "expense", transaction_date: Date.new(2026, 7, 2), amount: 25, description: "Lunch")
    Financial::Transaction.create!(account: @account, destination_account: checking, transaction_type: "income", transaction_date: Date.new(2026, 7, 1), amount: 100, description: "Income")

    other = Account.create!(name: "Other reporting household")
    other_category = Category.create!(account: other, name: "Hidden")
    other_checking = Financial::Account.create!(account: other, name: "Other checking", account_group: "asset", account_type: "checking", status: "active", opening_balance: 0)
    Financial::Transaction.create!(account: other, source_account: other_checking, category: other_category, transaction_type: "expense", transaction_date: Date.new(2026, 7, 2), amount: 900, description: "Hidden")
  end

  test "report projections are transaction-derived and account scoped" do
    overview = Financial::Reports::Overview.new(account: @account, date_from: "2026-07-01", date_to: "2026-07-31")
    by_date = Financial::Reports::ByDate.new(account: @account, date_from: "2026-07-01", date_to: "2026-07-31", period: "month")
    categories = Financial::Reports::SpendingByCategory.new(account: @account, date_from: "2026-07-01", date_to: "2026-07-31", period: "none")
    trends = Financial::Reports::CategoryTrend.new(account: @account, date_from: "2026-07-01", date_to: "2026-07-31", period: "month")

    assert_equal [ 25.0 ], overview.expenses_by_month_values
    assert_equal [ 100.0, 25.0 ], overview.income_vs_expenses_values
    assert_equal 25.0, by_date.buckets.sum { |bucket| bucket[:total_expenses] }
    assert_equal [ 25.0 ], categories.categories_summary.map { |category| category[:total] }
    assert_equal [ 25.0 ], trends.categories_summary.flat_map { |category| category[:amounts] }
  end

  test "invalid dates and periods fall back to safe defaults" do
    report = Financial::Reports::ByDate.new(account: @account, date_from: "not-a-date", date_to: "also-not-a-date", period: "unsupported")

    assert_equal Date.current.beginning_of_year, report.date_from
    assert_equal Date.current, report.date_to
    assert_equal "month", report.period
  end
end
