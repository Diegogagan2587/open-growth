class Habit::SkillAssignment < ApplicationRecord
  belongs_to :habit
  belongs_to :skill, optional: true
  validates :effective_on, presence: true, uniqueness: { scope: :habit_id }
  validate :same_owner

  private

  def same_owner
    return unless skill && habit
    errors.add(:skill, :invalid) unless skill.account_id == habit.account_id && skill.user_id == habit.user_id
  end
end
