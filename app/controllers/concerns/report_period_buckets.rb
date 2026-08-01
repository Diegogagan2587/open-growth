# frozen_string_literal: true

module ReportPeriodBuckets
  PERIODS = %w[day week biweekly quincenal month quarter year].freeze
  TREND_PERIODS = %w[week month quarter year].freeze
  BIWEEKLY_REFERENCE = Date.new(2000, 1, 3) # First Monday of 2000

  def report_set_date_range(default_from: Date.current.beginning_of_year, default_to: Date.current)
    @date_from = (params[:from].presence && Date.parse(params[:from])) || default_from
    @date_to   = (params[:to].presence && Date.parse(params[:to])) || default_to
    @date_from, @date_to = @date_to, @date_from if @date_from > @date_to
  end

  def report_buckets(date_from:, date_to:, period:)
    return [] unless PERIODS.include?(period)

    case period
    when "day"       then buckets_day(date_from, date_to)
    when "week"      then buckets_week(date_from, date_to)
    when "biweekly"  then buckets_biweekly(date_from, date_to)
    when "quincenal" then buckets_quincenal(date_from, date_to)
    when "month"     then buckets_month(date_from, date_to)
    when "quarter"  then buckets_quarter(date_from, date_to)
    when "year"      then buckets_year(date_from, date_to)
    else []
    end
  end

  # Returns SQL fragment for grouping expenses by period (alias for expense date column: "date")
  def report_period_group_sql(period, date_column: "date")
    return nil unless PERIODS.include?(period)

    case period
    when "day"
      "DATE_TRUNC('day', #{date_column})::date"
    when "week"
      "DATE_TRUNC('week', #{date_column})::date"
    when "biweekly"
      "(#{BIWEEKLY_REFERENCE} + (FLOOR((#{date_column}::date - '#{BIWEEKLY_REFERENCE}'::date) / 14)::integer * 14))"
    when "quincenal"
      "(DATE_TRUNC('month', #{date_column})::date + (CASE WHEN EXTRACT(day FROM #{date_column}) <= 15 THEN 0 ELSE 15 END) * interval '1 day')::date"
    when "month"
      "DATE_TRUNC('month', #{date_column})::date"
    when "quarter"
      "DATE_TRUNC('quarter', #{date_column})::date"
    when "year"
      "DATE_TRUNC('year', #{date_column})::date"
    else
      nil
    end
  end

  def report_period_label(date_or_range, period)
    case period
    when "day"
      I18n.l(date_or_range, format: :short)
    when "week"
      d = date_or_range.is_a?(Range) ? date_or_range.begin : date_or_range
      "#{I18n.l(d, format: :short)} – #{I18n.l(d + 6.days, format: :short)}"
    when "biweekly"
      d = date_or_range.is_a?(Range) ? date_or_range.begin : date_or_range
      e = date_or_range.is_a?(Range) ? date_or_range.end : d + 13.days
      "#{I18n.l(d, format: :short)} – #{I18n.l(e, format: :short)}"
    when "quincenal"
      d = date_or_range.is_a?(Range) ? date_or_range.begin : date_or_range
      I18n.l(d, format: "%b %Y") + (d.day == 16 ? " (16–)" : " (1–15)")
    when "month"
      d = date_or_range.is_a?(Range) ? date_or_range.begin : date_or_range
      I18n.l(d, format: "%b %Y")
    when "quarter"
      d = date_or_range.is_a?(Range) ? date_or_range.begin : date_or_range
      "Q#{(d.month / 3.0).ceil} #{d.year}"
    when "year"
      d = date_or_range.is_a?(Range) ? date_or_range.begin : date_or_range
      d.year.to_s
    else
      date_or_range.to_s
    end
  end

  private

  def buckets_day(date_from, date_to)
    (date_from..date_to).map do |d|
      { key: d, label: report_period_label(d, "day"), date_from: d, date_to: d }
    end
  end

  def buckets_week(date_from, date_to)
    start_monday = date_from - ((date_from.wday + 6) % 7)
    buckets = []
    cursor = start_monday
    while cursor <= date_to
      end_sunday = cursor + 6.days
      if end_sunday >= date_from
        b_from = [ cursor, date_from ].max
        b_to   = [ end_sunday, date_to ].min
        buckets << {
          key: cursor,
          label: report_period_label(cursor, "week"),
          date_from: b_from,
          date_to: b_to
        }
      end
      cursor += 7.days
    end
    buckets
  end

  def buckets_biweekly(date_from, date_to)
    # Align to BIWEEKLY_REFERENCE
    n = ((date_from - BIWEEKLY_REFERENCE).to_i / 14) * 14
    start_ref = BIWEEKLY_REFERENCE + n
    buckets = []
    cursor = start_ref
    while cursor <= date_to
      end_date = cursor + 13.days
      if end_date >= date_from
        b_from = [ cursor, date_from ].max
        b_to   = [ end_date, date_to ].min
        buckets << {
          key: cursor,
          label: report_period_label(cursor..end_date, "biweekly"),
          date_from: b_from,
          date_to: b_to
        }
      end
      cursor += 14.days
    end
    buckets
  end

  def buckets_quincenal(date_from, date_to)
    buckets = []
    cursor = date_from.beginning_of_month
    while cursor <= date_to
      # First half: 1–15
      half1_start = cursor
      half1_end   = [ cursor + 14.days, cursor.end_of_month ].min
      if half1_end >= date_from
        b_from = [ half1_start, date_from ].max
        b_to   = [ half1_end, date_to ].min
        buckets << {
          key: half1_start,
          label: report_period_label(half1_start, "quincenal"),
          date_from: b_from,
          date_to: b_to
        }
      end
      # Second half: 16–end
      half2_start = cursor + 15.days
      half2_end   = cursor.end_of_month
      if half2_start <= date_to && half2_end >= date_from
        b_from = [ half2_start, date_from ].max
        b_to   = [ half2_end, date_to ].min
        buckets << {
          key: half2_start,
          label: report_period_label(half2_start, "quincenal"),
          date_from: b_from,
          date_to: b_to
        }
      end
      cursor = cursor.next_month.beginning_of_month
    end
    buckets
  end

  def buckets_month(date_from, date_to)
    buckets = []
    cursor = date_from.beginning_of_month
    while cursor <= date_to
      b_from = [ cursor, date_from ].max
      b_to   = [ cursor.end_of_month, date_to ].min
      buckets << {
        key: cursor,
        label: report_period_label(cursor, "month"),
        date_from: b_from,
        date_to: b_to
      }
      cursor = cursor.next_month.beginning_of_month
    end
    buckets
  end

  def buckets_quarter(date_from, date_to)
    buckets = []
    cursor = date_from.beginning_of_quarter
    while cursor <= date_to
      b_from = [ cursor, date_from ].max
      b_to   = [ cursor.end_of_quarter, date_to ].min
      buckets << {
        key: cursor,
        label: report_period_label(cursor, "quarter"),
        date_from: b_from,
        date_to: b_to
      }
      cursor = (cursor + 3.months).beginning_of_quarter
    end
    buckets
  end

  def buckets_year(date_from, date_to)
    buckets = []
    cursor = date_from.beginning_of_year
    while cursor <= date_to
      b_from = [ cursor, date_from ].max
      b_to   = [ cursor.end_of_year, date_to ].min
      buckets << {
        key: cursor,
        label: report_period_label(cursor, "year"),
        date_from: b_from,
        date_to: b_to
      }
      cursor = (cursor + 1.year).beginning_of_year
    end
    buckets
  end
end
