class CreateHabits < ActiveRecord::Migration[8.1]
  def change
    create_table :habit_skills do |t|
      t.references :account, null: false, foreign_key: true
      t.references :user, null: false, foreign_key: true
      t.string :name, null: false
      t.timestamps
    end

    create_table :habits do |t|
      t.references :account, null: false, foreign_key: true
      t.references :user, null: false, foreign_key: true
      t.string :name, null: false
      t.text :notes
      t.string :kind, null: false, default: "simple"
      t.string :unit
      t.decimal :target, precision: 10, scale: 2
      t.integer :target_sets
      t.integer :target_reps
      t.time :scheduled_time
      t.date :starts_on, null: false
      t.date :archived_on
      t.timestamps
    end

    create_table :habit_schedule_versions do |t|
      t.references :habit, null: false, foreign_key: true
      t.date :effective_on, null: false
      t.integer :weekdays, array: true, null: false, default: []
      t.timestamps
      t.index [ :habit_id, :effective_on ], unique: true
    end

    create_table :habit_skill_assignments do |t|
      t.references :habit, null: false, foreign_key: true
      t.references :habit_skill, foreign_key: true
      t.date :effective_on, null: false
      t.timestamps
      t.index [ :habit_id, :effective_on ], unique: true
    end

    create_table :habit_check_ins do |t|
      t.references :habit, null: false, foreign_key: true
      t.date :on_date, null: false
      t.boolean :done, null: false, default: false
      t.decimal :amount, precision: 10, scale: 2
      t.timestamps
      t.index [ :habit_id, :on_date ], unique: true
    end

    create_table :habit_sets do |t|
      t.references :habit_check_in, null: false, foreign_key: true
      t.integer :position, null: false
      t.integer :reps, null: false
      t.decimal :weight, precision: 10, scale: 2
      t.timestamps
      t.index [ :habit_check_in_id, :position ], unique: true
    end

    create_table :habit_level_goals do |t|
      t.references :habit_skill, null: false, foreign_key: true
      t.references :habit, foreign_key: true
      t.integer :level, null: false
      t.string :description, null: false
      t.string :metric
      t.decimal :target, precision: 10, scale: 2
      t.date :achieved_on
      t.timestamps
    end
  end
end
