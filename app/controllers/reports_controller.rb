# frozen_string_literal: true

class ReportsController < ApplicationController
  include ReportPeriodBuckets

  before_action :require_account

  # Colores fijos por categoría (mismo category_id = mismo color en todas las gráficas)
  CATEGORY_CHART_PALETTE = [
    [ 34, 197, 94 ],   # green
    [ 234, 179, 8 ],   # amber
    [ 239, 68, 68 ],   # red
    [ 139, 92, 246 ],  # violet
    [ 236, 72, 153 ],  # pink
    [ 59, 130, 246 ],  # blue
    [ 20, 184, 166 ],  # teal
    [ 249, 115, 22 ],  # orange
    [ 168, 85, 247 ],  # purple
    [ 14, 165, 233 ],  # sky
    [ 132, 204, 22 ],  # lime
    [ 244, 63, 94 ]   # rose
  ].freeze

  def index
    @date_from = (params[:from].presence && Date.parse(params[:from])) || Date.current.beginning_of_year
    @date_to   = (params[:to].presence && Date.parse(params[:to])) || Date.current
    @date_from, @date_to = @date_to, @date_from if @date_from > @date_to
    range = @date_from..@date_to

    expenses = Financial::Entry.for_account(Current.account).where(entry_date: range, entry_type: %w[outflow liability_charge ])

    # Expenses by month (labels and values for Chart.js)
    by_month = expenses.group("DATE_TRUNC('month', entry_date)").order(Arel.sql("DATE_TRUNC('month', entry_date)")).sum(:amount)
    @expenses_by_month_labels = by_month.keys.map { |d| I18n.l(d.to_date, format: "%b %Y") }
    @expenses_by_month_values = by_month.values.map(&:to_f)

    # Expenses by category (con id para color estable por categoría)
    by_category = expenses.joins(:category).group("categories.id", "categories.name").order(Arel.sql("SUM(financial_entries.amount) DESC")).sum(:amount)
    @expenses_by_category_labels = by_category.keys.map { |(_, name)| name }
    @expenses_by_category_values = by_category.values.map(&:to_f)
    @expenses_by_category_ids = by_category.keys.map { |(id, _)| id }

    # Income vs expenses (for the same date range: income by effective date)
    income_total = IncomeEvent.for_account(Current.account).where(
      "COALESCE(received_date, expected_date) BETWEEN ? AND ?", @date_from, @date_to
    ).sum(Arel.sql("COALESCE(received_amount, expected_amount)"))
    expenses_total = expenses.sum(:amount)
    @income_vs_expenses_labels = [ I18n.t("reports.income"), I18n.t("reports.expenses") ]
    @income_vs_expenses_values = [ income_total.to_f, expenses_total.to_f ]

    # Chart.js configs for Stimulus (type + data.labels + data.datasets)
    @chart_expenses_over_time = {
      type: "bar",
      data: {
        labels: @expenses_by_month_labels,
        datasets: [ { label: I18n.t("reports.expenses"), data: @expenses_by_month_values, backgroundColor: "rgba(59, 130, 246, 0.5)", borderColor: "rgb(59, 130, 246)" } ]
      }
    }
    @chart_by_category = {
      type: "bar",
      data: {
        labels: @expenses_by_category_labels,
        datasets: [ {
          label: I18n.t("reports.expenses"),
          data: @expenses_by_category_values,
          backgroundColor: @expenses_by_category_ids.map { |id| category_chart_rgba(id) },
          borderColor: @expenses_by_category_ids.map { |id| category_chart_rgb(id) }
        } ]
      }
    }
    @chart_income_vs_expenses = {
      type: "bar",
      data: {
        labels: @income_vs_expenses_labels,
        datasets: [ { label: I18n.t("reports.amount"), data: @income_vs_expenses_values, backgroundColor: [ "rgba(34, 197, 94, 0.5)", "rgba(239, 68, 68, 0.5)" ], borderColor: [ "rgb(34, 197, 94)", "rgb(239, 68, 68)" ] } ]
      }
    }
  end

  def by_date
    report_set_date_range
    @period = params[:period].presence || "month"
    @period = "month" unless ReportPeriodBuckets::PERIODS.include?(@period)
    @buckets = report_buckets(date_from: @date_from, date_to: @date_to, period: @period)

    expenses = Expense.for_account(Current.account).where(date: @date_from..@date_to)
    group_sql = report_period_group_sql(@period)
    sums = expenses.group(group_sql).sum(:amount)

    @buckets.each do |b|
      key = b[:key]
      key = key.to_date if key.respond_to?(:to_date)
      b[:total_expenses] = (sums[key] || sums[key.to_s] || 0).to_f
    end

    @chart_config = {
      type: "bar",
      data: {
        labels: @buckets.map { |b| b[:label] },
        datasets: [
          {
            label: I18n.t("reports.expenses"),
            data: @buckets.map { |b| b[:total_expenses] },
            backgroundColor: "rgba(59, 130, 246, 0.5)",
            borderColor: "rgb(59, 130, 246)"
          }
        ]
      }
    }
  end

  def spending_by_category
    report_set_date_range
    @period = params[:period].presence || "none"
    @period = "none" unless @period == "none" || ReportPeriodBuckets::PERIODS.include?(@period)
    expenses = Expense.for_account(Current.account).where(date: @date_from..@date_to).joins(:category)

    if @period == "none"
      by_cat = expenses.group("categories.id", "categories.name").sum(:amount)
      @categories_summary = by_cat.map do |(cat_id, cat_name), total|
        { category_id: cat_id, category_name: cat_name, total: total.to_f, buckets: [] }
      end.sort_by { |c| -c[:total] }
      @period_labels = []
      @chart_config = build_spending_by_category_chart_totals(@categories_summary)
    else
      @buckets = report_buckets(date_from: @date_from, date_to: @date_to, period: @period)
      @period_labels = @buckets.map { |b| b[:label] }
      group_sql = report_period_group_sql(@period)
      # (bucket_key, category_id, category_name) -> sum
      rows = expenses.group(group_sql, "categories.id", "categories.name").sum(:amount)
      cat_data = {}
      rows.each do |(bucket_key, cat_id, cat_name), sum|
        key = bucket_key.to_date if bucket_key.respond_to?(:to_date)
        key ||= bucket_key
        cat_data[cat_id] ||= { category_id: cat_id, category_name: cat_name, total: 0, buckets: [] }
        cat_data[cat_id][:total] += sum.to_f
        bucket = @buckets.find { |b| (b[:key].to_date rescue b[:key]) == (key.to_date rescue key) }
        next unless bucket

        cat_data[cat_id][:buckets] << {
          label: bucket[:label],
          amount: sum.to_f,
          date_from: bucket[:date_from],
          date_to: bucket[:date_to]
        }
      end
      @categories_summary = cat_data.values.sort_by { |c| -c[:total] }
      @chart_config = build_spending_by_category_chart_stacked(@buckets, @categories_summary)
    end
  end

  def category_trends
    report_set_date_range
    @period = params[:period].presence || "month"
    @period = "month" unless ReportPeriodBuckets::TREND_PERIODS.include?(@period)
    @buckets = report_buckets(date_from: @date_from, date_to: @date_to, period: @period)
    @period_labels = @buckets.map { |b| b[:label] }

    expenses = Expense.for_account(Current.account).where(date: @date_from..@date_to).joins(:category)
    group_sql = report_period_group_sql(@period)
    rows = expenses.group(group_sql, "categories.id", "categories.name").sum(:amount)

    # Per category: array of amounts in bucket order; and total
    cat_series = {}
    rows.each do |(bucket_key, cat_id, cat_name), sum|
      bk = bucket_key.respond_to?(:to_date) ? bucket_key.to_date : bucket_key
      idx = @buckets.index { |b| (b[:key].respond_to?(:to_date) ? b[:key].to_date : b[:key]) == bk }
      next unless idx

      cat_series[cat_id] ||= { category_id: cat_id, category_name: cat_name, amounts: Array.new(@buckets.size, 0), total: 0 }
      cat_series[cat_id][:amounts][idx] = sum.to_f
      cat_series[cat_id][:total] += sum.to_f
    end
    @categories_summary = cat_series.values.sort_by { |c| -c[:total] }
    @chart_config = build_category_trends_chart(@buckets, @categories_summary)
  end

  private

  def category_chart_rgb(category_id)
    r, g, b = CATEGORY_CHART_PALETTE[(category_id.to_i % CATEGORY_CHART_PALETTE.size)]
    "rgb(#{r}, #{g}, #{b})"
  end

  def category_chart_rgba(category_id, alpha = 0.5)
    r, g, b = CATEGORY_CHART_PALETTE[(category_id.to_i % CATEGORY_CHART_PALETTE.size)]
    "rgba(#{r}, #{g}, #{b}, #{alpha})"
  end

  def require_account
    head :forbidden unless Current.account
  end

  def build_spending_by_category_chart_totals(categories_summary)
    {
      type: "bar",
      data: {
        labels: categories_summary.map { |c| c[:category_name] },
        datasets: [
          {
            label: I18n.t("reports.expenses"),
            data: categories_summary.map { |c| c[:total] },
            backgroundColor: categories_summary.map { |c| category_chart_rgba(c[:category_id]) },
            borderColor: categories_summary.map { |c| category_chart_rgb(c[:category_id]) }
          }
        ]
      }
    }
  end

  def build_spending_by_category_chart_stacked(buckets, categories_summary)
    datasets = categories_summary.map do |cat|
      amounts_by_label = cat[:buckets].index_by { |b| b[:label] }
      {
        label: cat[:category_name],
        data: buckets.map { |b| amounts_by_label[b[:label]]&.dig(:amount) || 0 },
        backgroundColor: category_chart_rgba(cat[:category_id], 0.7),
        borderColor: category_chart_rgb(cat[:category_id])
      }
    end
    {
      type: "bar",
      data: {
        labels: buckets.map { |b| b[:label] },
        datasets: datasets
      },
      options: { scales: { x: { stacked: true }, y: { stacked: true, beginAtZero: true } } }
    }
  end

  def build_category_trends_chart(buckets, categories_summary)
    datasets = categories_summary.map do |cat|
      color = category_chart_rgb(cat[:category_id])
      {
        label: cat[:category_name],
        data: cat[:amounts],
        fill: false,
        tension: 0.35,
        pointRadius: 0,
        borderColor: color,
        backgroundColor: color
      }
    end
    {
      type: "line",
      data: {
        labels: buckets.map { |b| b[:label] },
        datasets: datasets
      }
    }
  end
end
