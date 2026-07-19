class IntroduceFinancialPlannedTransactions < ActiveRecord::Migration[8.0]
  def up
    add_column :planned_expenses, :kind, :string
    add_column :planned_expenses, :planned_for, :date
    add_column :planned_expenses, :importance, :string, null: false, default: "normal"
    add_column :planned_expenses, :execution_status, :string, null: false, default: "pending"

    execute <<~SQL
      UPDATE planned_expenses
      SET kind = CASE
        WHEN financial_account_id IS NOT NULL AND counterparty_financial_account_id IS NOT NULL THEN 'transfer'
        WHEN financial_account_id IS NOT NULL AND financial_liability_id IS NOT NULL THEN 'liability_payment'
        WHEN financial_liability_id IS NOT NULL THEN 'liability_charge'
        ELSE 'outflow'
      END,
      planned_for = COALESCE(due_date, (
        SELECT expected_date FROM income_events WHERE income_events.id = planned_expenses.income_event_id
      )),
      execution_status = CASE
        WHEN status IN ('spent', 'paid', 'transferred') THEN 'applied'
        WHEN status = 'cancelled' THEN 'cancelled'
        WHEN status = 'skipped' THEN 'skipped'
        ELSE 'pending'
      END
    SQL

    execute <<~SQL
      WITH ordered AS (
        SELECT id, ROW_NUMBER() OVER (
          PARTITION BY income_event_id
          ORDER BY position NULLS LAST, created_at, id
        ) AS new_position
        FROM planned_expenses
      )
      UPDATE planned_expenses
      SET position = ordered.new_position
      FROM ordered
      WHERE planned_expenses.id = ordered.id
    SQL

    change_column_null :planned_expenses, :kind, false
    change_column_null :planned_expenses, :income_event_id, true
    add_index :planned_expenses,
      [ :income_event_id, :position ],
      unique: true,
      where: "income_event_id IS NOT NULL",
      name: "index_planned_transactions_on_plan_position"
    add_index :planned_expenses, [ :account_id, :execution_status ], name: "index_planned_transactions_on_execution_status"
  end

  def down
    remove_index :planned_expenses, name: "index_planned_transactions_on_execution_status"
    remove_index :planned_expenses, name: "index_planned_transactions_on_plan_position"
    change_column_null :planned_expenses, :income_event_id, false
    remove_column :planned_expenses, :execution_status
    remove_column :planned_expenses, :importance
    remove_column :planned_expenses, :planned_for
    remove_column :planned_expenses, :kind
  end
end
