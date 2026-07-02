class CreateCareerProfiles < ActiveRecord::Migration[8.1]
  def change
    create_table :career_profiles do |t|
      t.references :account, null: false, foreign_key: true, index: { unique: true }
      t.string :linkedin_url
      t.string :github_url
      t.string :website_url
      t.string :portfolio_url
      t.string :resume_url
      t.string :email
      t.string :phone
      t.string :location
      t.string :headline
      t.text :bio
      t.text :cover_letter_snippet
      t.text :salary_preferences
      t.text :notes

      t.timestamps
    end

  end
end
