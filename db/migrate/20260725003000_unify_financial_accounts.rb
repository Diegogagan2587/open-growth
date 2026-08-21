class UnifyFinancialAccounts < ActiveRecord::Migration[8.1]
  LIABILITY_REFERENCE_COLUMNS = {
    expenses: %i[financial_liability_id counterparty_financial_liability_id],
    financial_entries: %i[financial_liability_id counterparty_financial_liability_id],
    financial_funding_sources: %i[expected_destination_liability_id],
    financial_loans: %i[liability_id destination_liability_id],
    financial_planned_transactions: %i[liability_id],
    income_events: %i[loan_liability_id loan_disbursement_destination_liability_id regular_income_destination_liability_id],
    planned_expenses: %i[financial_liability_id]
  }.freeze

  def up
    remove_index :financial_accounts, column: [ :account_id, :name ]
    add_column :financial_accounts, :account_group, :string, null: false, default: "asset"
    add_column :financial_accounts, :credit_limit, :decimal, precision: 12, scale: 2
    add_column :financial_accounts, :archived_at, :datetime
    add_column :financial_accounts, :legacy_liability_id, :bigint
    add_index :financial_accounts, :legacy_liability_id, unique: true, where: "legacy_liability_id IS NOT NULL"
    add_index :financial_accounts, [ :account_id, :account_group, :name ], unique: true, name: "index_financial_accounts_on_group_and_name"
    add_index :financial_accounts, [ :account_id, :account_group ], name: "index_financial_accounts_on_account_and_group"

    execute <<~SQL
      INSERT INTO financial_accounts (
        account_id, name, account_group, account_type, opening_balance, credit_limit,
        status, notes, archived_at, legacy_liability_id, created_at, updated_at
      )
      SELECT
        account_id, name, 'liability', liability_type, opening_balance, credit_limit,
        status, notes, archived_at, id, created_at, updated_at
      FROM financial_liabilities
    SQL

    add_reference :financial_entries, :source_account, foreign_key: { to_table: :financial_accounts }
    add_reference :financial_entries, :destination_account, foreign_key: { to_table: :financial_accounts }
    add_reference :financial_funding_sources, :expected_destination_account, foreign_key: { to_table: :financial_accounts }
    add_reference :financial_planned_transactions, :source_account, foreign_key: { to_table: :financial_accounts }
    add_reference :financial_planned_transactions, :destination_account, foreign_key: { to_table: :financial_accounts }
    add_reference :financial_loans, :liability_account, foreign_key: { to_table: :financial_accounts }
    add_reference :financial_loans, :destination_account, foreign_key: { to_table: :financial_accounts }

    remove_legacy_liability_foreign_keys
    remap_legacy_liability_references
    populate_canonical_routes
    add_unified_account_foreign_keys
  end

  def down
    raise ActiveRecord::IrreversibleMigration, "financial account IDs are remapped from legacy liabilities"
  end

  private

  def remap_legacy_liability_references
    LIABILITY_REFERENCE_COLUMNS.each do |table, columns|
      columns.each do |column|
        execute <<~SQL
          UPDATE #{table} records
          SET #{column} = accounts.id
          FROM financial_accounts accounts
          WHERE accounts.legacy_liability_id = records.#{column}
            AND records.#{column} IS NOT NULL
        SQL
      end
    end
  end

  def populate_canonical_routes
    execute <<~SQL
      UPDATE financial_entries
      SET source_account_id = CASE entry_type
            WHEN 'outflow' THEN financial_account_id
            WHEN 'transfer' THEN financial_account_id
            WHEN 'liability_charge' THEN financial_liability_id
            WHEN 'liability_payment' THEN financial_account_id
            WHEN 'loan_disbursement' THEN financial_liability_id
            ELSE NULL
          END,
          destination_account_id = CASE entry_type
            WHEN 'inflow' THEN COALESCE(financial_account_id, counterparty_financial_liability_id)
            WHEN 'transfer' THEN counterparty_financial_account_id
            WHEN 'liability_payment' THEN financial_liability_id
            WHEN 'loan_disbursement' THEN COALESCE(financial_account_id, counterparty_financial_liability_id)
            WHEN 'adjustment' THEN financial_account_id
            ELSE NULL
          END
    SQL

    execute <<~SQL
      UPDATE financial_funding_sources
      SET expected_destination_account_id = COALESCE(expected_destination_asset_id, expected_destination_liability_id)
    SQL

    execute <<~SQL
      UPDATE financial_planned_transactions
      SET source_account_id = COALESCE(source_asset_id, liability_id),
          destination_account_id = COALESCE(destination_asset_id,
            CASE WHEN source_asset_id IS NOT NULL THEN liability_id END)
    SQL

    execute <<~SQL
      UPDATE financial_loans
      SET liability_account_id = liability_id,
          destination_account_id = COALESCE(destination_asset_id, destination_liability_id)
    SQL
  end

  def remove_legacy_liability_foreign_keys
    LIABILITY_REFERENCE_COLUMNS.each do |table, columns|
      columns.each do |column|
        remove_foreign_key table, column: column if foreign_key_exists?(table, column: column)
      end
    end
  end

  def add_unified_account_foreign_keys
    LIABILITY_REFERENCE_COLUMNS.each do |table, columns|
      columns.each do |column|
        add_foreign_key table, :financial_accounts, column: column
      end
    end
  end
end
