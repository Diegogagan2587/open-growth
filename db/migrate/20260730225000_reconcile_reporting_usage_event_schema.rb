class ReconcileReportingUsageEventSchema < ActiveRecord::Migration[8.1]
  def up
    unless column_exists?(:reporting_usage_events, :user_id)
      add_reference :reporting_usage_events, :user, null: true, foreign_key: true
      execute <<~SQL.squish
        UPDATE reporting_usage_events
        SET user_id = account_memberships.user_id
        FROM account_memberships
        WHERE reporting_usage_events.account_membership_id = account_memberships.id
      SQL
      change_column_null :reporting_usage_events, :user_id, false
    end

    change_column_null :reporting_usage_events, :account_membership_id, true
    replace_foreign_key :account_memberships, column: :account_membership_id
    replace_foreign_key :reporting_conversations, column: :conversation_id
    replace_foreign_key :reporting_turns, column: :turn_id
  end

  def down
    raise ActiveRecord::IrreversibleMigration, "usage retention constraints cannot be safely reversed"
  end

  private

  def replace_foreign_key(to_table, column:)
    remove_foreign_key :reporting_usage_events, column: column if foreign_key_exists?(:reporting_usage_events, to_table, column: column)
    add_foreign_key :reporting_usage_events, to_table, column: column, on_delete: :nullify
  end
end
