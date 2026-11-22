class Habit::Skill < ApplicationRecord
  belongs_to :account
  belongs_to :user
  has_many :skill_assignments, dependent: :nullify
  has_many :level_goals, dependent: :destroy
  validates :name, presence: true, uniqueness: { scope: [ :account_id, :user_id ] }
  scope :for_current, -> { where(account: Current.account, user: Current.user) }

  def xp
    entries = Habit::CheckIn.joins(:habit).where(habits: { account_id: account_id, user_id: user_id }).includes(habit: { skill_assignments: :skill }).to_a
    exercise_entries = entries.select { |entry| entry.habit.kind == "exercise" }
    ActiveRecord::Associations::Preloader.new(records: exercise_entries, associations: :sets).call if exercise_entries.any?
    entries.sum do |entry|
      entry.complete? && entry.habit.skill_on(entry.on_date)&.id == id ? 10 : 0
    end
  end

  def level
    1 + xp / 100
  end
end
