class Habit::SkillAssignment < ApplicationRecord
  belongs_to :habit
  belongs_to :habit_skill, class_name: "Habit::Skill", optional: true
  validates :effective_on, presence: true, uniqueness: { scope: :habit_id }
  validate :same_owner

  private

  def same_owner
    return unless habit_skill && habit
    errors.add(:habit_skill, :invalid) unless habit_skill.account_id == habit.account_id && habit_skill.user_id == habit.user_id
  end
end
