class AddProviderSettingsToAiConfigurations < ActiveRecord::Migration[8.1]
  def change
    add_column :ai_configurations, :provider, :string, null: false, default: "openai"
    add_column :ai_configurations, :model, :string, null: false, default: "gpt-5.6-luna"
    add_column :ai_configurations, :openai_api_key, :text
  end
end
