class Habit::ScheduleVersion < ApplicationRecord
  belongs_to :habit
  validates :effective_on, presence: true, uniqueness: { scope: :habit_id }
  validate :valid_weekdays

  private

  def valid_weekdays
    errors.add(:weekdays, :invalid) unless weekdays.present? && weekdays.uniq == weekdays && weekdays.all? { |day| (0..6).cover?(day) }
  end
end
