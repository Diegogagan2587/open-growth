class UnifyFinancialAccounts < ActiveRecord::Migration[8.1]
  LIABILITY_REFERENCES = {
    expenses: %i[financial_liability_id counterparty_financial_liability_id],
    financial_entries: %i[financial_liability_id counterparty_financial_liability_id],
    financial_funding_sources: %i[expected_destination_liability_id],
    financial_loans: %i[liability_id destination_liability_id],
    financial_loan_installments: %i[],
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

    execute <<~SQL
      INSERT INTO financial_accounts (
        account_id, account_group, account_type, name, opening_balance, credit_limit,
        status, notes, archived_at, legacy_liability_id, created_at, updated_at
      )
      SELECT account_id, 'liability', liability_type, name, opening_balance, credit_limit,
             status, notes, archived_at, id, created_at, updated_at
      FROM financial_liabilities
    SQL

    LIABILITY_REFERENCES.each do |table, columns|
      columns.each do |column|
        remove_foreign_key table, column: column if foreign_key_exists?(table, column: column)
        execute <<~SQL
          UPDATE #{table} records
          SET #{column} = accounts.id
          FROM financial_accounts accounts
          WHERE accounts.legacy_liability_id = records.#{column}
            AND records.#{column} IS NOT NULL
        SQL
        add_foreign_key table, :financial_accounts, column: column
      end
    end
  end

  def down
    raise ActiveRecord::IrreversibleMigration, "financial liability IDs are remapped into financial accounts"
  end
end
