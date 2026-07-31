class AddTurnsCountToReportingConversations < ActiveRecord::Migration[8.1]
  def up
    add_column :reporting_conversations, :turns_count, :integer, null: false, default: 0

    execute <<~SQL.squish
      UPDATE reporting_conversations
      SET turns_count = turn_counts.count
      FROM (
        SELECT conversation_id, COUNT(*) AS count
        FROM reporting_turns
        GROUP BY conversation_id
      ) AS turn_counts
      WHERE reporting_conversations.id = turn_counts.conversation_id
    SQL
  end

  def down
    remove_column :reporting_conversations, :turns_count
  end
end
