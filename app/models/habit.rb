class Habit < ApplicationRecord
  KINDS = %w[simple measured exercise].freeze
  UNITS = %w[minutes km].freeze

  belongs_to :account
  belongs_to :user
  has_many :schedule_versions, class_name: "Habit::ScheduleVersion", dependent: :destroy
  has_many :skill_assignments, class_name: "Habit::SkillAssignment", dependent: :destroy
  has_many :check_ins, class_name: "Habit::CheckIn", dependent: :destroy
  has_many :level_goals, class_name: "Habit::LevelGoal", dependent: :nullify

  validates :name, presence: true
  validates :kind, inclusion: { in: KINDS }
  validates :starts_on, presence: true
  validates :unit, inclusion: { in: UNITS }, if: -> { kind == "measured" }
  validates :target, numericality: { greater_than: 0 }, if: -> { kind == "measured" }
  validates :target_sets, :target_reps, numericality: { only_integer: true, greater_than: 0 }, if: -> { kind == "exercise" }
  validate :tracking_type_unchanged_after_check_ins, on: :update

  scope :for_current, -> { where(account: Current.account, user: Current.user) }
  scope :active, -> { where(archived_on: nil) }

  def schedule_on(date)
    return schedule_versions.select { |version| version.effective_on <= date }.max_by(&:effective_on) if schedule_versions.loaded?
    schedule_versions.where(effective_on: ..date).order(effective_on: :desc).first
  end

  def scheduled_on?(date)
    date >= starts_on && (archived_on.nil? || date < archived_on) && schedule_on(date)&.weekdays&.include?(date.wday)
  end

  def skill_on(date)
    assignment = if skill_assignments.loaded?
      skill_assignments.select { |version| version.effective_on <= date }.max_by(&:effective_on)
    else
      skill_assignments.where(effective_on: ..date).order(effective_on: :desc).first
    end
    assignment&.habit_skill
  end

  def completed_on?(date)
    entry = check_ins.loaded? ? check_ins.find { |item| item.on_date == date } : check_ins.find_by(on_date: date)
    entry&.complete? || false
  end

  def streak(today)
    date = today
    date -= 1.day if scheduled_on?(date) && !completed_on?(date)
    count = 0
    while date >= starts_on
      if scheduled_on?(date)
        break unless completed_on?(date)
        count += 1
      end
      date -= 1.day
    end
    count
  end

  def completion_rate(today)
    dates = ([(today - 29.days), starts_on].max..today).select { |date| scheduled_on?(date) }
    return 0 if dates.empty?

    (100.0 * dates.count { |date| completed_on?(date) } / dates.size).round
  end

  private

  def tracking_type_unchanged_after_check_ins
    return unless (will_save_change_to_kind? || will_save_change_to_unit?) && check_ins.exists?
    errors.add(:kind, :invalid)
  end
end
