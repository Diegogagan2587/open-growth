class Financial::Reports::SpendingByCategory < Financial::Reports::Base
  attr_reader :period, :buckets, :period_labels, :categories_summary, :chart_config

  def initialize(period: nil, **)
    super(**)
    @period = period == "none" || period.in?(ReportPeriodBuckets::PERIODS) ? period : "none"
    @period ||= "none"
    build
  end

  private

  def build
    categorized_expenses = expenses.joins(:category)
    if period == "none"
      totals = categorized_expenses.group("categories.id", "categories.name").sum(:amount)
      @categories_summary = totals.map do |(category_id, category_name), total|
        { category_id: category_id, category_name: category_name, total: total.to_f, buckets: [] }
      end.sort_by { |category| -category[:total] }
      @period_labels = []
      @chart_config = totals_chart
      return
    end

    @buckets = report_buckets(date_from: date_from, date_to: date_to, period: period)
    @period_labels = buckets.map { |bucket| bucket[:label] }
    rows = categorized_expenses
      .group(report_period_group_sql(period, date_column: "transaction_date"), "categories.id", "categories.name")
      .sum(:amount)
    category_data = {}
    rows.each do |(bucket_key, category_id, category_name), sum|
      key = bucket_key.respond_to?(:to_date) ? bucket_key.to_date : bucket_key
      category_data[category_id] ||= { category_id: category_id, category_name: category_name, total: 0, buckets: [] }
      category_data[category_id][:total] += sum.to_f
      bucket = buckets.find { |candidate| comparable_key(candidate[:key]) == comparable_key(key) }
      next unless bucket

      category_data[category_id][:buckets] << {
        label: bucket[:label], amount: sum.to_f, date_from: bucket[:date_from], date_to: bucket[:date_to]
      }
    end
    @categories_summary = category_data.values.sort_by { |category| -category[:total] }
    @chart_config = stacked_chart
  end

  def totals_chart
    {
      type: "bar",
      data: {
        labels: categories_summary.map { |category| category[:category_name] },
        datasets: [ {
          label: I18n.t("reports.expenses"),
          data: categories_summary.map { |category| category[:total] },
          backgroundColor: categories_summary.map { |category| category_chart_rgba(category[:category_id]) },
          borderColor: categories_summary.map { |category| category_chart_rgb(category[:category_id]) }
        } ]
      }
    }
  end

  def stacked_chart
    datasets = categories_summary.map do |category|
      amounts_by_label = category[:buckets].index_by { |bucket| bucket[:label] }
      {
        label: category[:category_name],
        data: buckets.map { |bucket| amounts_by_label[bucket[:label]]&.dig(:amount) || 0 },
        backgroundColor: category_chart_rgba(category[:category_id], 0.7),
        borderColor: category_chart_rgb(category[:category_id])
      }
    end
    {
      type: "bar",
      data: { labels: buckets.map { |bucket| bucket[:label] }, datasets: datasets },
      options: { scales: { x: { stacked: true }, y: { stacked: true, beginAtZero: true } } }
    }
  end

  def comparable_key(value)
    value.respond_to?(:to_date) ? value.to_date : value
  end
end
