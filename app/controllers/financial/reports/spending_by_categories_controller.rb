class Financial::Reports::SpendingByCategoriesController < ApplicationController
  def show
    report = Financial::Reports::SpendingByCategory.new(account: Current.account, date_from: params[:from], date_to: params[:to], period: params[:period])
    @date_from = report.date_from
    @date_to = report.date_to
    @period = report.period
    @buckets = report.buckets
    @period_labels = report.period_labels
    @categories_summary = report.categories_summary
    @chart_config = report.chart_config
    render "reports/spending_by_category"
  end
end
