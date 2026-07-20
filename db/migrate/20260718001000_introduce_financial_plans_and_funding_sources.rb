class IntroduceFinancialPlansAndFundingSources < ActiveRecord::Migration[8.0]
  def up
    add_column :income_events, :lifecycle_status, :string, null: false, default: "active"
    add_column :income_events, :closed_at, :datetime
    add_column :income_events, :actual_ending_balance_at_close, :decimal, precision: 12, scale: 2
    add_index :income_events, [ :account_id, :expected_date, :id ], name: "index_income_events_on_plan_chronology"

    create_table :financial_funding_sources do |t|
      t.references :account, null: false, foreign_key: true
      t.references :financial_plan, null: false, foreign_key: { to_table: :income_events }
      t.bigint :financial_loan_id
      t.bigint :legacy_income_event_id
      t.string :description, null: false
      t.decimal :expected_amount, precision: 12, scale: 2, null: false
      t.date :expected_date, null: false
      t.string :kind, null: false, default: "income"
      t.string :resolution, null: false, default: "pending"
      t.references :expected_destination_asset, foreign_key: { to_table: :financial_accounts }
      t.references :expected_destination_liability, foreign_key: { to_table: :financial_liabilities }
      t.timestamps
    end
    add_index :financial_funding_sources, :financial_loan_id
    add_index :financial_funding_sources, :legacy_income_event_id, unique: true

    add_reference :financial_entries, :funding_source, foreign_key: { to_table: :financial_funding_sources }
    add_index :financial_entries,
      :funding_source_id,
      unique: true,
      where: "funding_source_id IS NOT NULL",
      name: "index_financial_entries_on_unique_funding_source"

    execute <<~SQL
      INSERT INTO financial_funding_sources (
        account_id, financial_plan_id, legacy_income_event_id, description,
        expected_amount, expected_date, kind, resolution,
        expected_destination_asset_id, expected_destination_liability_id,
        created_at, updated_at
      )
      SELECT
        ie.account_id, ie.id, ie.id, ie.description,
        ie.expected_amount, ie.expected_date,
        CASE WHEN ie.income_type = 'loan' THEN 'borrowed' ELSE 'income' END,
        CASE WHEN EXISTS (
          SELECT 1 FROM financial_entries fe
          WHERE fe.income_event_id = ie.id
            AND fe.entry_type = CASE WHEN ie.income_type = 'loan' THEN 'loan_disbursement' ELSE 'inflow' END
        ) THEN 'received' ELSE 'pending' END,
        CASE WHEN ie.income_type = 'loan'
          THEN ie.loan_disbursement_destination_asset_id
          ELSE ie.regular_income_destination_asset_id
        END,
        CASE WHEN ie.income_type = 'loan'
          THEN ie.loan_disbursement_destination_liability_id
          ELSE ie.regular_income_destination_liability_id
        END,
        ie.created_at, ie.updated_at
      FROM income_events ie
      ON CONFLICT (legacy_income_event_id) DO NOTHING
    SQL

    execute <<~SQL
      UPDATE financial_entries fe
      SET funding_source_id = fs.id
      FROM financial_funding_sources fs
      WHERE fe.income_event_id = fs.legacy_income_event_id
        AND fe.funding_source_id IS NULL
        AND fe.entry_type = CASE WHEN fs.kind = 'borrowed' THEN 'loan_disbursement' ELSE 'inflow' END
    SQL
  end

  def down
    remove_reference :financial_entries, :funding_source, foreign_key: { to_table: :financial_funding_sources }
    drop_table :financial_funding_sources
    remove_index :income_events, name: "index_income_events_on_plan_chronology"
    remove_column :income_events, :actual_ending_balance_at_close
    remove_column :income_events, :closed_at
    remove_column :income_events, :lifecycle_status
  end
end
