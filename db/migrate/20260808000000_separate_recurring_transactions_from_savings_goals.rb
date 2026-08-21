class SeparateRecurringTransactionsFromSavingsGoals < ActiveRecord::Migration[8.1]
  def up
    create_table :financial_recurring_transactions do |t|
      t.references :account, null: false, foreign_key: true
      t.references :category, foreign_key: true
      t.references :source_account, foreign_key: { to_table: :financial_accounts }
      t.references :destination_account, foreign_key: { to_table: :financial_accounts }
      t.string :name, null: false
      t.string :description
      t.decimal :amount, precision: 12, scale: 2, null: false
      t.string :frequency, null: false
      t.string :transaction_kind, null: false
      t.boolean :budget_consuming, null: false
      t.string :importance, null: false, default: "normal"
      t.string :status, null: false, default: "active"
      t.text :notes
      t.timestamps
    end

    add_index :financial_recurring_transactions, [ :account_id, :status, :name ], name: "index_financial_recurring_transactions_for_picker"
    add_check_constraint :financial_recurring_transactions, "amount > 0", name: "financial_recurring_transactions_positive_amount"
    add_check_constraint :financial_recurring_transactions,
      "frequency IN ('weekly', 'biweekly', 'quincenal', 'monthly', 'bimonthly', 'quarterly', 'custom')",
      name: "financial_recurring_transactions_valid_frequency"
    add_check_constraint :financial_recurring_transactions,
      "transaction_kind IN ('outflow', 'liability_charge', 'transfer', 'liability_payment')",
      name: "financial_recurring_transactions_valid_kind"
    add_check_constraint :financial_recurring_transactions,
      "importance IN ('low', 'normal', 'high', 'essential')",
      name: "financial_recurring_transactions_valid_importance"
    add_check_constraint :financial_recurring_transactions,
      "status IN ('active', 'archived')",
      name: "financial_recurring_transactions_valid_status"
    add_check_constraint :financial_recurring_transactions,
      "source_account_id IS NULL OR destination_account_id IS NULL OR source_account_id <> destination_account_id",
      name: "financial_recurring_transactions_distinct_accounts"

    add_reference :financial_planned_transactions, :recurring_transaction,
      foreign_key: { to_table: :financial_recurring_transactions }
    add_column :financial_planned_transactions, :budget_consuming, :boolean
    execute <<~SQL
      UPDATE financial_planned_transactions
      SET budget_consuming = kind IN ('outflow', 'liability_charge')
    SQL
    change_column_null :financial_planned_transactions, :budget_consuming, false

    migrate_legacy_expense_templates
    rewire_legacy_planned_expenses
    remove_migrated_savings_goals
  end

  def down
    raise ActiveRecord::IrreversibleMigration,
      "recurring transactions and savings goals have independent lifecycles"
  end

  private

  def migrate_legacy_expense_templates
    execute <<~SQL
      INSERT INTO financial_recurring_transactions (
        id, account_id, category_id, source_account_id, destination_account_id,
        name, description, amount, frequency, transaction_kind, budget_consuming,
        importance, status, notes, created_at, updated_at
      )
      SELECT
        goals.id,
        goals.account_id,
        goals.category_id,
        occurrence.source_account_id,
        occurrence.destination_account_id,
        goals.name,
        goals.description,
        goals.total_amount,
        goals.frequency,
        COALESCE(occurrence.kind, 'outflow'),
        COALESCE(occurrence.kind IN ('outflow', 'liability_charge'), TRUE),
        COALESCE(occurrence.importance, 'normal'),
        'active',
        goals.notes,
        goals.created_at,
        goals.updated_at
      FROM financial_savings_goals goals
      LEFT JOIN LATERAL (
        SELECT planned.kind, planned.importance, planned.source_account_id, planned.destination_account_id
        FROM financial_planned_transactions planned
        WHERE planned.savings_goal_id = goals.id
        ORDER BY planned.created_at DESC, planned.id DESC
        LIMIT 1
      ) occurrence ON TRUE
    SQL

    execute <<~SQL
      UPDATE financial_planned_transactions
      SET recurring_transaction_id = savings_goal_id,
          savings_goal_id = NULL
      WHERE savings_goal_id IS NOT NULL
    SQL

    execute <<~SQL
      SELECT setval(
        pg_get_serial_sequence('financial_recurring_transactions', 'id'),
        COALESCE((SELECT MAX(id) FROM financial_recurring_transactions), 1),
        EXISTS (SELECT 1 FROM financial_recurring_transactions)
      )
    SQL
  end

  def remove_migrated_savings_goals
    execute "DELETE FROM financial_savings_goals"
  end

  def rewire_legacy_planned_expenses
    remove_foreign_key :planned_expenses, column: :expense_template_id if foreign_key_exists?(:planned_expenses, column: :expense_template_id)
    add_foreign_key :planned_expenses, :financial_recurring_transactions, column: :expense_template_id
  end
end
