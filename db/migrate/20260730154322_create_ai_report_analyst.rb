class CreateAiReportAnalyst < ActiveRecord::Migration[8.1]
  def change
    add_column :users, :system_admin, :boolean, null: false, default: false
    add_column :accounts, :ai_reports_enabled, :boolean, null: false, default: false
    add_column :account_memberships, :ai_reports_enabled, :boolean, null: false, default: false
    add_column :account_memberships, :ai_reports_monthly_request_limit, :integer, null: false, default: 50

    create_table :ai_configurations do |t|
      t.string :key, null: false, default: "default"
      t.boolean :reports_enabled, null: false, default: false
      t.integer :default_monthly_request_limit, null: false, default: 50
      t.integer :maximum_monthly_request_limit, null: false, default: 500
      t.timestamps
    end
    add_index :ai_configurations, :key, unique: true

    create_table :reporting_conversations do |t|
      t.references :account, null: false, foreign_key: true
      t.references :account_membership, null: false, foreign_key: true
      t.string :title, null: false
      t.date :date_from, null: false
      t.date :date_to, null: false
      t.timestamps
    end
    add_index :reporting_conversations, [ :account_membership_id, :updated_at ]

    create_table :reporting_turns do |t|
      t.references :conversation, null: false, foreign_key: { to_table: :reporting_conversations }
      t.text :question, null: false
      t.text :answer
      t.string :status, null: false, default: "queued"
      t.string :model
      t.string :provider_response_id
      t.string :error_code
      t.text :error_message
      t.datetime :processing_started_at
      t.timestamps
    end
    add_index :reporting_turns, [ :status, :created_at ]

    create_table :reporting_usage_events do |t|
      t.references :account, null: false, foreign_key: true
      t.references :user, null: false, foreign_key: true
      t.references :account_membership, null: true, foreign_key: { on_delete: :nullify }
      t.references :conversation, null: true, foreign_key: { to_table: :reporting_conversations, on_delete: :nullify }
      t.references :turn, null: true, foreign_key: { to_table: :reporting_turns, on_delete: :nullify }
      t.string :status, null: false, default: "reserved"
      t.string :model, null: false
      t.string :provider_response_id
      t.integer :input_tokens, null: false, default: 0
      t.integer :output_tokens, null: false, default: 0
      t.integer :cached_input_tokens, null: false, default: 0
      t.string :error_code
      t.datetime :provider_called_at
      t.timestamps
    end
    add_index :reporting_usage_events, [ :account_membership_id, :created_at ], name: "idx_reporting_usage_membership_month"
  end
end
