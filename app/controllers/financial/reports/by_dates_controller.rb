class Financial::Reports::ByDatesController < ApplicationController
  def show
    report = Financial::Reports::ByDate.new(account: Current.account, date_from: params[:from], date_to: params[:to], period: params[:period])
    @date_from = report.date_from
    @date_to = report.date_to
    @period = report.period
    @buckets = report.buckets
    @chart_config = report.chart_config
    render "reports/by_date"
  end
end
