class Habit::ActivityCalendar
  COLORS = %w[#eff2f5 #aceebb #4ac26b #2da44e #116329].freeze

  attr_reader :today, :weeks

  def initialize(account:, user:, today:)
    @today = today
    first_day = today.beginning_of_week(:sunday) - 51.weeks
    @weeks = 52.times.map { |week| 7.times.map { |day| first_day + week.weeks + day.days } }
    entries = Habit::CheckIn.joins(:habit)
      .where(habits: { account_id: account.id, user_id: user.id })
      .where(on_date: first_day..today)
      .includes(:habit)
      .to_a
    exercise_entries = entries.select { |entry| entry.habit.kind == "exercise" }
    ActiveRecord::Associations::Preloader.new(records: exercise_entries, associations: :sets).call if exercise_entries.any?
    @counts = entries.select(&:complete?).group_by(&:on_date).transform_values(&:size)
  end

  def count_on(date)
    @counts.fetch(date, 0)
  end

  def color_on(date)
    COLORS[[ count_on(date), 4 ].min]
  end
end
