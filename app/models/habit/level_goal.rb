class Habit::LevelGoal < ApplicationRecord
  METRICS = %w[amount reps weight].freeze
  belongs_to :habit_skill, class_name: "Habit::Skill"
  belongs_to :habit, optional: true
  validates :description, presence: true
  validates :level, numericality: { only_integer: true, greater_than: 0 }
  validates :metric, inclusion: { in: METRICS }, allow_nil: true
  validates :target, numericality: { greater_than: 0 }, if: :metric?
  validate :valid_link

  def progress
    return nil unless habit && metric
    entries = habit.check_ins.includes(:sets)
    values = entries.flat_map do |entry|
      case metric
      when "amount" then [ entry.amount ]
      when "reps" then entry.sets.map(&:reps)
      when "weight" then entry.sets.map(&:weight)
      end
    end.compact
    values.max || 0
  end

  def achieved?
    achieved_on.present? || (metric.present? && progress >= target)
  end

  def actual_achieved_on
    return achieved_on if achieved_on.present?
    return nil unless habit && metric && target

    habit.check_ins.includes(:sets).order(:on_date).find do |entry|
      case metric
      when "amount" then entry.amount && entry.amount >= target
      when "reps" then entry.sets.any? { |set| set.reps >= target }
      when "weight" then entry.sets.any? { |set| set.weight && set.weight >= target }
      end
    end&.on_date
  end

  private

  def valid_link
    return unless habit && habit_skill
    errors.add(:habit, :invalid) unless habit.account_id == habit_skill.account_id && habit.user_id == habit_skill.user_id
    errors.add(:metric, :invalid) if metric == "amount" && habit.kind != "measured"
    errors.add(:metric, :invalid) if %w[reps weight].include?(metric) && habit.kind != "exercise"
  end
end
