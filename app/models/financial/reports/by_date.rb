class Financial::Reports::ByDate < Financial::Reports::Base
  attr_reader :period, :buckets, :chart_config

  def initialize(period: nil, **)
    super(**)
    @period = period.presence_in(ReportPeriodBuckets::PERIODS) || "month"
    build
  end

  private

  def build
    @buckets = report_buckets(date_from: date_from, date_to: date_to, period: period)
    sums = expenses.group(report_period_group_sql(period, date_column: "transaction_date")).sum(:amount)
    @buckets.each do |bucket|
      key = bucket[:key].respond_to?(:to_date) ? bucket[:key].to_date : bucket[:key]
      bucket[:total_expenses] = (sums[key] || sums[key.to_s] || 0).to_f
    end
    @chart_config = {
      type: "bar",
      data: {
        labels: buckets.map { |bucket| bucket[:label] },
        datasets: [ {
          label: I18n.t("reports.expenses"),
          data: buckets.map { |bucket| bucket[:total_expenses] },
          backgroundColor: "rgba(59, 130, 246, 0.5)",
          borderColor: "rgb(59, 130, 246)"
        } ]
      }
    }
  end
end
