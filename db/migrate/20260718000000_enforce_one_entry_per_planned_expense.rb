class EnforceOneEntryPerPlannedExpense < ActiveRecord::Migration[8.0]
  REVIEW_MARKER = "[Planning migration review required]".freeze

  def up
    entries_requiring_review.each do |entry|
      say "Unlinking financial entry #{entry.fetch('id')} from duplicate planned expense #{entry.fetch('planned_expense_id')} for manual review"
    end

    execute <<~SQL
      WITH ranked_entries AS (
        SELECT
          id,
          planned_expense_id,
          ROW_NUMBER() OVER (
            PARTITION BY planned_expense_id
            ORDER BY created_at, id
          ) AS entry_rank
        FROM financial_entries
        WHERE planned_expense_id IS NOT NULL
      )
      UPDATE financial_entries
      SET
        planned_expense_id = NULL,
        notes = CASE
          WHEN COALESCE(financial_entries.notes, '') LIKE '%#{REVIEW_MARKER}%'
            THEN financial_entries.notes
          ELSE CONCAT_WS(
            E'\n',
            NULLIF(financial_entries.notes, ''),
            CONCAT(
              '#{REVIEW_MARKER} Unlinked from planned transaction ',
              ranked_entries.planned_expense_id,
              ' because multiple actual entries were associated. Verify whether this entry is legitimate or duplicated.'
            )
          )
        END
      FROM ranked_entries
      WHERE financial_entries.id = ranked_entries.id
        AND ranked_entries.entry_rank > 1
    SQL

    add_index :financial_entries,
      :planned_expense_id,
      unique: true,
      where: "planned_expense_id IS NOT NULL",
      name: "index_financial_entries_on_unique_planned_expense"
  end

  def down
    remove_index :financial_entries, name: "index_financial_entries_on_unique_planned_expense"
  end

  private

  def entries_requiring_review
    select_all <<~SQL
      SELECT id, planned_expense_id
      FROM (
        SELECT
          id,
          planned_expense_id,
          ROW_NUMBER() OVER (
            PARTITION BY planned_expense_id
            ORDER BY created_at, id
          ) AS entry_rank
        FROM financial_entries
        WHERE planned_expense_id IS NOT NULL
      ) ranked_entries
      WHERE entry_rank > 1
      ORDER BY planned_expense_id, id
    SQL
  end
end
