class SnapshotHabitCheckInTargets < ActiveRecord::Migration[8.1]
  def change
    add_column :habit_check_ins, :target_amount, :decimal, precision: 10, scale: 2
    add_column :habit_check_ins, :target_sets, :integer
    add_column :habit_check_ins, :target_reps, :integer
  end
end
