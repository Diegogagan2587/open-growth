class Financial::Reports::Overview < Financial::Reports::Base
  attr_reader :expenses_by_month_labels, :expenses_by_month_values,
    :expenses_by_category_labels, :expenses_by_category_values,
    :income_vs_expenses_labels, :income_vs_expenses_values,
    :chart_expenses_over_time, :chart_by_category, :chart_income_vs_expenses

  def initialize(...)
    super
    build
  end

  private

  def build
    by_month = expenses
      .group("DATE_TRUNC('month', transaction_date)")
      .order(Arel.sql("DATE_TRUNC('month', transaction_date)"))
      .sum(:amount)
    @expenses_by_month_labels = by_month.keys.map { |date| I18n.l(date.to_date, format: "%b %Y") }
    @expenses_by_month_values = by_month.values.map(&:to_f)

    by_category = expenses
      .joins(:category)
      .group("categories.id", "categories.name")
      .order(Arel.sql("SUM(financial_transactions.amount) DESC"))
      .sum(:amount)
    @expenses_by_category_labels = by_category.keys.map { |(_, name)| name }
    @expenses_by_category_values = by_category.values.map(&:to_f)
    category_ids = by_category.keys.map(&:first)

    income_total = transactions.where(transaction_type: %w[income loan_disbursement refund]).sum(:amount)
    @income_vs_expenses_labels = [ I18n.t("reports.income"), I18n.t("reports.expenses") ]
    @income_vs_expenses_values = [ income_total.to_f, expenses.sum(:amount).to_f ]

    @chart_expenses_over_time = bar_chart(@expenses_by_month_labels, @expenses_by_month_values)
    @chart_by_category = bar_chart(
      @expenses_by_category_labels,
      @expenses_by_category_values,
      background: category_ids.map { |id| category_chart_rgba(id) },
      border: category_ids.map { |id| category_chart_rgb(id) }
    )
    @chart_income_vs_expenses = bar_chart(
      @income_vs_expenses_labels,
      @income_vs_expenses_values,
      background: [ "rgba(34, 197, 94, 0.5)", "rgba(239, 68, 68, 0.5)" ],
      border: [ "rgb(34, 197, 94)", "rgb(239, 68, 68)" ]
    )
  end

  def bar_chart(labels, values, background: "rgba(59, 130, 246, 0.5)", border: "rgb(59, 130, 246)")
    {
      type: "bar",
      data: {
        labels: labels,
        datasets: [ { label: I18n.t("reports.expenses"), data: values, backgroundColor: background, borderColor: border } ]
      }
    }
  end
end
