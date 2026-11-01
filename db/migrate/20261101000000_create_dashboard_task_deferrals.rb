# frozen_string_literal: true

class CreateDashboardTaskDeferrals < ActiveRecord::Migration[8.0]
  def change
    create_table :dashboard_task_deferrals do |t|
      t.references :account, null: false, foreign_key: true
      t.references :user, null: false, foreign_key: true
      t.string :task_type, null: false
      t.bigint :task_id, null: false
      t.datetime :deferred_at, null: false
      t.timestamps
    end

    add_index :dashboard_task_deferrals,
      [ :account_id, :user_id, :task_type, :task_id ],
      unique: true,
      name: "index_dashboard_task_deferrals_on_account_user_task"
  end
end
