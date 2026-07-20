class SeparateFinancialLoansAndInstallments < ActiveRecord::Migration[8.0]
  def up
    create_table :financial_loans do |t|
      t.references :account, null: false, foreign_key: true
      t.bigint :legacy_income_event_id
      t.references :liability, foreign_key: { to_table: :financial_liabilities }
      t.references :destination_asset, foreign_key: { to_table: :financial_accounts }
      t.references :destination_liability, foreign_key: { to_table: :financial_liabilities }
      t.string :name, null: false
      t.string :lender_name
      t.decimal :principal_amount, precision: 12, scale: 2, null: false
      t.decimal :interest_rate, precision: 6, scale: 3
      t.integer :number_of_payments
      t.string :payment_frequency
      t.decimal :payment_amount, precision: 12, scale: 2
      t.string :lifecycle_status, null: false, default: "simulated"
      t.text :notes
      t.timestamps
    end
    add_index :financial_loans, :legacy_income_event_id, unique: true

    add_foreign_key :financial_funding_sources, :financial_loans
    add_reference :financial_entries, :financial_loan, foreign_key: true

    create_table :financial_loan_installments do |t|
      t.references :account, null: false, foreign_key: true
      t.references :financial_loan, null: false, foreign_key: true
      t.bigint :legacy_loan_payment_schedule_id
      t.references :planned_transaction, foreign_key: { to_table: :planned_expenses }
      t.references :payment_entry, foreign_key: { to_table: :financial_entries }
      t.integer :installment_number, null: false
      t.date :due_date, null: false
      t.decimal :expected_amount, precision: 12, scale: 2, null: false
      t.decimal :expected_principal, precision: 12, scale: 2, null: false, default: 0
      t.decimal :expected_interest, precision: 12, scale: 2, null: false, default: 0
      t.string :resolution, null: false, default: "scheduled"
      t.timestamps
    end
    add_index :financial_loan_installments, :legacy_loan_payment_schedule_id, unique: true, name: "index_loan_installments_on_legacy_schedule"
    add_index :financial_loan_installments, [ :financial_loan_id, :installment_number ], unique: true, name: "index_loan_installments_on_number"

    execute <<~SQL
      INSERT INTO financial_loans (
        account_id, legacy_income_event_id, liability_id, destination_asset_id,
        destination_liability_id, name, lender_name, principal_amount,
        interest_rate, number_of_payments, payment_frequency, payment_amount,
        lifecycle_status, notes, created_at, updated_at
      )
      SELECT
        ie.account_id, ie.id, ie.loan_liability_id,
        ie.loan_disbursement_destination_asset_id, ie.loan_disbursement_destination_liability_id,
        ie.description, ie.lender_name, COALESCE(ie.loan_amount, ie.expected_amount),
        ie.interest_rate, ie.number_of_payments, ie.payment_frequency, ie.payment_amount,
        CASE WHEN EXISTS (
          SELECT 1 FROM financial_entries fe
          WHERE fe.income_event_id = ie.id AND fe.entry_type = 'loan_disbursement'
        ) THEN 'active' ELSE 'simulated' END,
        ie.notes, ie.created_at, ie.updated_at
      FROM income_events ie
      WHERE ie.income_type = 'loan'
      ON CONFLICT (legacy_income_event_id) DO NOTHING
    SQL

    execute <<~SQL
      UPDATE financial_funding_sources fs
      SET financial_loan_id = loan.id
      FROM financial_loans loan
      WHERE fs.legacy_income_event_id = loan.legacy_income_event_id
        AND fs.financial_loan_id IS NULL
    SQL

    execute <<~SQL
      UPDATE financial_entries fe
      SET financial_loan_id = loan.id
      FROM financial_loans loan
      WHERE fe.income_event_id = loan.legacy_income_event_id
        AND fe.financial_loan_id IS NULL
        AND fe.entry_type IN ('loan_disbursement', 'liability_payment', 'liability_charge')
    SQL

    execute <<~SQL
      INSERT INTO financial_loan_installments (
        account_id, financial_loan_id, legacy_loan_payment_schedule_id,
        planned_transaction_id, payment_entry_id, installment_number, due_date,
        expected_amount, expected_principal, expected_interest, resolution,
        created_at, updated_at
      )
      SELECT
        schedule.account_id, loan.id, schedule.id, planned.id, entry.id,
        schedule.installment_number, schedule.due_date, schedule.amount,
        schedule.principal_amount, schedule.interest_amount,
        CASE WHEN entry.id IS NOT NULL THEN 'paid' ELSE 'scheduled' END,
        schedule.created_at, schedule.updated_at
      FROM loan_payment_schedules schedule
      JOIN financial_loans loan ON loan.legacy_income_event_id = schedule.loan_id
      LEFT JOIN LATERAL (
        SELECT pe.id
        FROM planned_expenses pe
        WHERE pe.loan_installment_number = schedule.installment_number
          AND (pe.origin_income_event_id = schedule.loan_id OR pe.income_event_id = schedule.loan_id)
        ORDER BY (pe.origin_income_event_id = schedule.loan_id) DESC, pe.id
        LIMIT 1
      ) planned ON TRUE
      LEFT JOIN financial_entries entry ON entry.planned_expense_id = planned.id
      ON CONFLICT (legacy_loan_payment_schedule_id) DO NOTHING
    SQL
  end

  def down
    drop_table :financial_loan_installments
    remove_reference :financial_entries, :financial_loan, foreign_key: true
    remove_foreign_key :financial_funding_sources, :financial_loans
    drop_table :financial_loans
  end
end
