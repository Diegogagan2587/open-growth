class UseConventionalSkillForeignKeys < ActiveRecord::Migration[8.1]
  def change
    rename_column :habit_skill_assignments, :habit_skill_id, :skill_id
    rename_column :habit_level_goals, :habit_skill_id, :skill_id
  end
end
