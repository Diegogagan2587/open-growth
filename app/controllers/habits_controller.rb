class HabitsController < ApplicationController
  before_action :set_habit, only: %i[show edit update archive]

  def index
    @today = habit_today
    @habits = Habit.for_current.active.includes(:check_ins, :schedule_versions, { skill_assignments: :skill }).to_a
    @due = @habits.select { |habit| habit.scheduled_on?(@today) }
      .sort_by { |habit| [ habit.scheduled_time ? 0 : 1, habit.scheduled_time || Time.zone.parse("23:59"), habit.name ] }
    @skills = Habit::Skill.for_current.order(:name)
    @archived = Habit.for_current.where.not(archived_on: nil).order(archived_on: :desc)
    @activity_calendar = Habit::ActivityCalendar.new(account: Current.account, user: Current.user, today: @today)
  end

  def show
    @today = habit_today
    @start = [ @today - 29.days, @habit.starts_on ].max
    @habit.schedule_versions.load
    @habit.check_ins.load
    ActiveRecord::Associations::Preloader.new(records: @habit.check_ins.to_a, associations: :sets).call
    @check_ins = @habit.check_ins.index_by(&:on_date)
  end

  def new
    @habit = Habit.new(starts_on: habit_today, kind: "simple")
    form_options
  end

  def create
    @habit = Habit.for_current.new(habit_params.except(:weekdays, :habit_skill_id))
    @habit.starts_on ||= habit_today
    @habit.transaction do
      @habit.save!
      @habit.schedule_versions.create!(effective_on: @habit.starts_on, weekdays: weekdays)
      @habit.skill_assignments.create!(effective_on: @habit.starts_on, skill: selected_skill) if params.dig(:habit, :habit_skill_id).present?
    end
    redirect_to @habit, notice: t("habits.saved")
  rescue ActiveRecord::RecordInvalid => error
    @habit.errors.add(:base, error.record.errors.full_messages.to_sentence) unless error.record == @habit
    form_options
    render :new, status: :unprocessable_entity
  end

  def edit
    form_options
  end

  def update
    @habit.transaction do
      @habit.update!(habit_params.except(:weekdays, :habit_skill_id, :starts_on))
      if weekdays != @habit.schedule_on(habit_today)&.weekdays
        @habit.schedule_versions.find_or_initialize_by(effective_on: habit_today).update!(weekdays: weekdays)
      end
      if selected_skill&.id != @habit.skill_on(habit_today)&.id
        @habit.skill_assignments.find_or_initialize_by(effective_on: habit_today).update!(skill: selected_skill)
      end
    end
    redirect_to @habit, notice: t("habits.saved")
  rescue ActiveRecord::RecordInvalid => error
    @habit.errors.add(:base, error.record.errors.full_messages.to_sentence) unless error.record == @habit
    form_options
    render :edit, status: :unprocessable_entity
  end

  def archive
    @habit.update!(archived_on: habit_today)
    redirect_to habits_path, notice: t("habits.archived")
  end

  private

  def set_habit
    @habit = Habit.for_current.find(params[:id])
  end

  def form_options
    @skills = Habit::Skill.for_current.order(:name)
    @selected_weekdays = @habit.persisted? ? @habit.schedule_on(habit_today)&.weekdays || [] : (0..6).to_a
  end

  def weekdays
    Array(params.dig(:habit, :weekdays)).reject(&:blank?).map(&:to_i).uniq.sort
  end

  def selected_skill
    return nil if params.dig(:habit, :habit_skill_id).blank?
    Habit::Skill.for_current.find(params.dig(:habit, :habit_skill_id))
  end

  def habit_today
    Time.find_zone!(Current.user.time_zone).today
  end

  def habit_params
    params.require(:habit).permit(:name, :notes, :kind, :unit, :target, :target_sets, :target_reps, :scheduled_time, :starts_on, :habit_skill_id, weekdays: [])
  end
end
