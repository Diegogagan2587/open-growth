class CreateCanonicalFinancialPlanning < ActiveRecord::Migration[8.1]
  def up
    create_table :financial_plans do |t|
      t.references :account, null: false, foreign_key: true
      t.references :budget_period, foreign_key: true
      t.string :name, null: false
      t.date :planned_for, null: false
      t.string :lifecycle_status, null: false, default: "active"
      t.datetime :closed_at
      t.decimal :actual_ending_balance_at_close, precision: 12, scale: 2
      t.text :notes
      t.bigint :legacy_income_event_id
      t.timestamps
    end
    add_index :financial_plans, :legacy_income_event_id, unique: true
    add_index :financial_plans, [ :account_id, :planned_for, :id ], name: "index_financial_plans_on_chronology"

    execute <<~SQL
      INSERT INTO financial_plans (
        id, account_id, budget_period_id, name, planned_for, lifecycle_status,
        closed_at, actual_ending_balance_at_close, notes, legacy_income_event_id,
        created_at, updated_at
      )
      SELECT
        id, account_id, budget_period_id, description, expected_date, lifecycle_status,
        closed_at, actual_ending_balance_at_close, notes, id, created_at, updated_at
      FROM income_events
    SQL
    reset_primary_key_sequence(:financial_plans)

    create_table :financial_planned_transactions do |t|
      t.references :account, null: false, foreign_key: true
      t.references :plan, foreign_key: { to_table: :financial_plans }
      t.references :origin_plan, foreign_key: { to_table: :financial_plans }
      t.references :category, foreign_key: true
      t.references :expense_template, foreign_key: true
      t.references :shopping_item, foreign_key: true
      t.references :source_asset, foreign_key: { to_table: :financial_accounts }
      t.references :destination_asset, foreign_key: { to_table: :financial_accounts }
      t.references :liability, foreign_key: { to_table: :financial_liabilities }
      t.string :description, null: false
      t.decimal :planned_amount, precision: 12, scale: 2, null: false
      t.string :kind, null: false
      t.date :planned_execution_date
      t.date :due_date
      t.string :importance, null: false, default: "normal"
      t.string :execution_status, null: false, default: "pending"
      t.integer :position
      t.text :notes
      t.bigint :legacy_planned_expense_id
      t.timestamps
    end
    add_index :financial_planned_transactions, :legacy_planned_expense_id, unique: true, name: "index_planned_transactions_on_legacy_expense"
    add_index :financial_planned_transactions, [ :account_id, :execution_status ], name: "index_financial_planned_transactions_on_execution"
    add_index :financial_planned_transactions, [ :plan_id, :position ], unique: true, where: "plan_id IS NOT NULL", name: "index_financial_planned_transactions_on_position"

    execute <<~SQL
      INSERT INTO financial_planned_transactions (
        id, account_id, plan_id, origin_plan_id, category_id, expense_template_id,
        shopping_item_id, source_asset_id, destination_asset_id, liability_id,
        description, planned_amount, kind, planned_execution_date, due_date,
        importance, execution_status, position, notes, legacy_planned_expense_id,
        created_at, updated_at
      )
      SELECT
        id, account_id, income_event_id, origin_income_event_id, category_id, expense_template_id,
        shopping_item_id, financial_account_id, counterparty_financial_account_id, financial_liability_id,
        description, amount, kind, planned_for, due_date,
        importance, execution_status, position, notes, id,
        created_at, updated_at
      FROM planned_expenses
    SQL
    reset_primary_key_sequence(:financial_planned_transactions)

    remove_foreign_key :financial_funding_sources, column: :financial_plan_id
    add_foreign_key :financial_funding_sources, :financial_plans, column: :financial_plan_id

    add_reference :financial_entries, :plan, foreign_key: { to_table: :financial_plans }
    add_reference :financial_entries, :planned_transaction, foreign_key: { to_table: :financial_planned_transactions }
    execute "UPDATE financial_entries SET plan_id = income_event_id, planned_transaction_id = planned_expense_id"
    add_index :financial_entries, :planned_transaction_id, unique: true, where: "planned_transaction_id IS NOT NULL", name: "index_financial_entries_on_unique_planned_transaction"

    remove_foreign_key :financial_loan_installments, column: :planned_transaction_id
    add_foreign_key :financial_loan_installments, :financial_planned_transactions, column: :planned_transaction_id

    add_reference :shopping_items, :planned_transaction, foreign_key: { to_table: :financial_planned_transactions }
    execute "UPDATE shopping_items SET planned_transaction_id = planned_expense_id"
  end

  def down
    remove_reference :shopping_items, :planned_transaction, foreign_key: { to_table: :financial_planned_transactions }
    remove_foreign_key :financial_loan_installments, column: :planned_transaction_id
    add_foreign_key :financial_loan_installments, :planned_expenses, column: :planned_transaction_id
    remove_reference :financial_entries, :planned_transaction, foreign_key: { to_table: :financial_planned_transactions }
    remove_reference :financial_entries, :plan, foreign_key: { to_table: :financial_plans }
    remove_foreign_key :financial_funding_sources, column: :financial_plan_id
    add_foreign_key :financial_funding_sources, :income_events, column: :financial_plan_id
    drop_table :financial_planned_transactions
    drop_table :financial_plans
  end

  private

  def reset_primary_key_sequence(table)
    execute <<~SQL
      SELECT setval(
        pg_get_serial_sequence('#{table}', 'id'),
        GREATEST(COALESCE((SELECT MAX(id) FROM #{table}), 0) + 1, 1),
        false
      )
    SQL
  end
end
