class RemovePortfolioUrlFromCareerProfiles < ActiveRecord::Migration[8.1]
  def change
    remove_column :career_profiles, :portfolio_url, :string
  end
end
