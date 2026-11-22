class Habit::Set < ApplicationRecord
  belongs_to :habit_check_in, class_name: "Habit::CheckIn"
  validates :position, numericality: { only_integer: true, greater_than: 0 }
  validates :reps, numericality: { only_integer: true, greater_than_or_equal_to: 0 }
  validates :weight, numericality: { greater_than_or_equal_to: 0 }, allow_nil: true
end
