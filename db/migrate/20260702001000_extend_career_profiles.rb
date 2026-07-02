class ExtendCareerProfiles < ActiveRecord::Migration[8.1]
  def change
    add_column :career_profiles, :elevator_pitch, :text
    add_column :career_profiles, :unique_selling_point, :text

    create_table :career_profile_links do |t|
      t.references :career_profile, null: false, foreign_key: true
      t.string :name, null: false
      t.string :url, null: false

      t.timestamps
    end

    create_table :career_carl_stories do |t|
      t.references :career_profile, null: false, foreign_key: true
      t.text :behavioral_question, null: false
      t.text :context
      t.text :action
      t.text :result
      t.text :learning

      t.timestamps
    end
  end
end
