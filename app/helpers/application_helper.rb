module ApplicationHelper
  THEME_PALETTE_OPTIONS = [
    [ "Executive Calm", "executive-calm" ],
    [ "Ocean Depth", "ocean-depth" ],
    [ "Forest Mint", "forest-mint" ],
    [ "Sunset Ember", "sunset-ember" ],
    [ "Shadcn Default", "shadcn-default" ]
  ].freeze

  # Returns the current page title for the navbar (e.g. "Expenses", "New expense").
  # Uses content_for(:nav_title) if set, otherwise derives from controller/action and locale.
  def nav_page_title
    return content_for(:nav_title) if content_for?(:nav_title)

    path = controller_path.tr("/", ".")
    action = action_name

    # Reports use custom locale keys (by_date_title, etc.)
    if controller_path == "reports"
      return t("reports.index.title") if action == "index"
      return t("reports.by_date_title") if action == "by_date"
      return t("reports.spending_by_category_title") if action == "spending_by_category"
      return t("reports.category_trends_title") if action == "category_trends"
    end

    # Standard key: e.g. expenses.index.title, budget_periods.show.title
    key = "#{path}.#{action}.title"
    return t(key) if I18n.exists?(key)

    # Fallback: nav section label by controller
    nav_key = case controller_path
    when "dashboard" then "dashboard"
    when "budget_periods" then "budgets"
    when "income_events" then "incomes"
    when "expenses", "financial/entries" then "expenses"
    when "categories" then "categories"
    when "task/areas", "task/recurring_tasks" then "tasks"
    when "reports" then "reports"
    when "accounts", "account_memberships" then "accounts"
    when "settings" then "settings"
    when "expense_templates" then "expenses" # or use expense_templates.index.title
    when "shopping_items" then "nav.dashboard" # no nav link; dashboard has shopping_list_title
    when "inventory_items" then "nav.dashboard"
    when "planned_expenses" then "incomes"
    else nil
    end

    nav_key ? t("nav.#{nav_key}") : t("nav.dashboard")
  end

  def report_period_options
    ReportPeriodBuckets::PERIODS.map { |p| [ I18n.t("reports.period_#{p}"), p ] }
  end

  def report_period_options_with_total
    [ [ I18n.t("reports.period_total"), "none" ] ] + report_period_options
  end

  def report_trend_period_options
    ReportPeriodBuckets::TREND_PERIODS.map { |p| [ I18n.t("reports.period_#{p}"), p ] }
  end

  def render_markdown(text)
    return "" if text.blank?

    markdown = Redcarpet::Markdown.new(
      Redcarpet::Render::HTML.new(hard_wrap: true),
      autolink: true,
      tables: true,
      fenced_code_blocks: true,
      strikethrough: true
    )

    # Sanitize the rendered HTML to prevent XSS attacks
    sanitize(
      markdown.render(text),
      tags: %w[h1 h2 h3 h4 h5 h6 p br strong em u del code pre blockquote ul ol li a table thead tbody tr th td hr],
      attributes: { "a" => [ "href", "title" ], "th" => [ "align" ], "td" => [ "align" ] }
    )
  end

  def theme_palette_options
    THEME_PALETTE_OPTIONS
  end

  def current_theme_palette
    raw_palette = Current.user&.theme_palette.presence || "executive-calm"
    palette = User::LEGACY_THEME_PALETTE_MAP.fetch(raw_palette, raw_palette)
    User::THEME_PALETTES.include?(palette) ? palette : "executive-calm"
  end

  def current_theme_palette_class
    "palette-#{current_theme_palette}"
  end

  def safe_external_url(url)
    value = url.to_s.strip
    return nil if value.blank?

    parsed = URI.parse(value)
    return nil unless parsed.is_a?(URI::HTTP) || parsed.is_a?(URI::HTTPS)

    parsed.to_s
  rescue URI::InvalidURIError
    nil
  end
end
