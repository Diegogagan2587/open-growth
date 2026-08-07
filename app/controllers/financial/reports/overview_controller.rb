class Financial::Reports::OverviewController < ApplicationController
  def show
    report = Financial::Reports::Overview.new(account: Current.account, date_from: params[:from], date_to: params[:to])
    @date_from = report.date_from
    @date_to = report.date_to
    @expenses_by_month_labels = report.expenses_by_month_labels
    @expenses_by_month_values = report.expenses_by_month_values
    @expenses_by_category_labels = report.expenses_by_category_labels
    @expenses_by_category_values = report.expenses_by_category_values
    @income_vs_expenses_labels = report.income_vs_expenses_labels
    @income_vs_expenses_values = report.income_vs_expenses_values
    @chart_expenses_over_time = report.chart_expenses_over_time
    @chart_by_category = report.chart_by_category
    @chart_income_vs_expenses = report.chart_income_vs_expenses
    render "reports/index"
  end
end
