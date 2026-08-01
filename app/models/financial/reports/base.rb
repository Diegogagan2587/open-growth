class Financial::Reports::Base
  include ReportPeriodBuckets

  CATEGORY_CHART_PALETTE = [
    [34, 197, 94], [234, 179, 8], [239, 68, 68], [139, 92, 246],
    [236, 72, 153], [59, 130, 246], [20, 184, 166], [249, 115, 22],
    [168, 85, 247], [14, 165, 233], [132, 204, 22], [244, 63, 94]
  ].freeze

  attr_reader :account, :date_from, :date_to

  def initialize(account:, date_from: nil, date_to: nil)
    @account = account
    @date_from = parse_date(date_from, Date.current.beginning_of_year)
    @date_to = parse_date(date_to, Date.current)
    @date_from, @date_to = @date_to, @date_from if @date_from > @date_to
  end

  private

  def transactions
    Financial::Transaction.for_account(account).where(transaction_date: date_from..date_to)
  end

  def expenses
    transactions.where(transaction_type: "expense")
  end

  def parse_date(value, fallback)
    value.present? ? Date.parse(value.to_s) : fallback
  rescue Date::Error
    fallback
  end

  def category_chart_rgb(category_id)
    red, green, blue = CATEGORY_CHART_PALETTE[category_id.to_i % CATEGORY_CHART_PALETTE.size]
    "rgb(#{red}, #{green}, #{blue})"
  end

  def category_chart_rgba(category_id, alpha = 0.5)
    red, green, blue = CATEGORY_CHART_PALETTE[category_id.to_i % CATEGORY_CHART_PALETTE.size]
    "rgba(#{red}, #{green}, #{blue}, #{alpha})"
  end
end
