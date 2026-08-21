require "test_helper"

class ReportPeriodBucketsTest < ActiveSupport::TestCase
  include ReportPeriodBuckets

  test "includes a partial first weekly bucket and advances through the range" do
    buckets = report_buckets(
      date_from: Date.new(2026, 8, 5),
      date_to: Date.new(2026, 8, 12),
      period: "week"
    )

    assert_equal [
      { key: Date.new(2026, 8, 3), date_from: Date.new(2026, 8, 5), date_to: Date.new(2026, 8, 9) },
      { key: Date.new(2026, 8, 10), date_from: Date.new(2026, 8, 10), date_to: Date.new(2026, 8, 12) }
    ], buckets.map { |bucket| bucket.slice(:key, :date_from, :date_to) }
  end

  test "includes a partial first biweekly bucket and advances through the range" do
    buckets = report_buckets(
      date_from: Date.new(2026, 8, 20),
      date_to: Date.new(2026, 9, 2),
      period: "biweekly"
    )

    assert_equal [
      { key: Date.new(2026, 8, 10), date_from: Date.new(2026, 8, 20), date_to: Date.new(2026, 8, 23) },
      { key: Date.new(2026, 8, 24), date_from: Date.new(2026, 8, 24), date_to: Date.new(2026, 9, 2) }
    ], buckets.map { |bucket| bucket.slice(:key, :date_from, :date_to) }
  end
end
