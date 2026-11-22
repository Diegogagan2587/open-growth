class Habit::CheckIn < ApplicationRecord
  belongs_to :habit
  has_many :sets, class_name: "Habit::Set", foreign_key: :habit_check_in_id, dependent: :destroy
  accepts_nested_attributes_for :sets, allow_destroy: true

  validates :on_date, presence: true, uniqueness: { scope: :habit_id }
  validates :amount, numericality: { greater_than_or_equal_to: 0 }, allow_nil: true
  validate :scheduled_date
  before_validation :snapshot_goal, on: :create

  def complete?
    case habit.kind
    when "simple" then done?
    when "measured" then amount.present? && amount >= (target_amount || habit.target)
    when "exercise" then sets.count { |set| set.reps >= (target_reps || habit.target_reps) } >= (target_sets || habit.target_sets)
    end
  end

  private

  def snapshot_goal
    case habit.kind
    when "measured" then self.target_amount = habit.target
    when "exercise"
      self.target_sets = habit.target_sets
      self.target_reps = habit.target_reps
    end
  end

  def scheduled_date
    errors.add(:on_date, :invalid) if on_date && (!habit.scheduled_on?(on_date) || on_date > Time.find_zone!(habit.user.time_zone).today)
  end
end
