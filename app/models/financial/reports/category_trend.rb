class Financial::Reports::CategoryTrend < Financial::Reports::Base
  attr_reader :period, :buckets, :period_labels, :categories_summary, :chart_config

  def initialize(period: nil, **)
    super(**)
    @period = period.presence_in(ReportPeriodBuckets::TREND_PERIODS) || "month"
    build
  end

  private

  def build
    @buckets = report_buckets(date_from: date_from, date_to: date_to, period: period)
    @period_labels = buckets.map { |bucket| bucket[:label] }
    rows = expenses
      .joins(:category)
      .group(report_period_group_sql(period, date_column: "transaction_date"), "categories.id", "categories.name")
      .sum(:amount)
    category_series = {}
    rows.each do |(bucket_key, category_id, category_name), sum|
      key = bucket_key.respond_to?(:to_date) ? bucket_key.to_date : bucket_key
      index = buckets.index { |bucket| comparable_key(bucket[:key]) == comparable_key(key) }
      next unless index

      category_series[category_id] ||= {
        category_id: category_id,
        category_name: category_name,
        amounts: Array.new(buckets.size, 0),
        total: 0
      }
      category_series[category_id][:amounts][index] = sum.to_f
      category_series[category_id][:total] += sum.to_f
    end
    @categories_summary = category_series.values.sort_by { |category| -category[:total] }
    @chart_config = {
      type: "line",
      data: {
        labels: buckets.map { |bucket| bucket[:label] },
        datasets: categories_summary.map { |category| chart_dataset(category) }
      }
    }
  end

  def chart_dataset(category)
    color = category_chart_rgb(category[:category_id])
    {
      label: category[:category_name], data: category[:amounts], fill: false,
      tension: 0.35, pointRadius: 0, borderColor: color, backgroundColor: color
    }
  end

  def comparable_key(value)
    value.respond_to?(:to_date) ? value.to_date : value
  end
end
