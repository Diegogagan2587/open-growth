# This file is auto-generated from the current state of the database. Instead
# of editing this file, please use the migrations feature of Active Record to
# incrementally modify your database, and then regenerate this schema definition.
#
# This file is the source Rails uses to define your schema when running `bin/rails
# db:schema:load`. When creating a new database, `bin/rails db:schema:load` tends to
# be faster and is potentially less error prone than running all of your
# migrations from scratch. Old migrations may fail to apply correctly if those
# migrations use external dependencies or application code.
#
# It's strongly recommended that you check this file into your version control system.

ActiveRecord::Schema[8.1].define(version: 2026_08_08_000000) do
  # These are extensions that must be enabled in order to support this database
  enable_extension "pg_catalog.plpgsql"

  create_table "account_memberships", force: :cascade do |t|
    t.bigint "account_id", null: false
    t.boolean "ai_reports_enabled", default: false, null: false
    t.integer "ai_reports_monthly_request_limit", default: 50, null: false
    t.datetime "created_at", null: false
    t.string "role", default: "member", null: false
    t.datetime "updated_at", null: false
    t.bigint "user_id", null: false
    t.index ["account_id"], name: "index_account_memberships_on_account_id"
    t.index ["user_id", "account_id"], name: "index_account_memberships_on_user_id_and_account_id", unique: true
    t.index ["user_id"], name: "index_account_memberships_on_user_id"
  end

  create_table "accounts", force: :cascade do |t|
    t.boolean "ai_reports_enabled", default: false, null: false
    t.datetime "created_at", null: false
    t.string "name", null: false
    t.datetime "updated_at", null: false
  end

  create_table "ai_configurations", force: :cascade do |t|
    t.datetime "created_at", null: false
    t.integer "default_monthly_request_limit", default: 50, null: false
    t.string "key", default: "default", null: false
    t.integer "maximum_monthly_request_limit", default: 500, null: false
    t.string "model", default: "gpt-5.6-luna", null: false
    t.text "openai_api_key"
    t.string "provider", default: "openai", null: false
    t.boolean "reports_enabled", default: false, null: false
    t.datetime "updated_at", null: false
    t.index ["key"], name: "index_ai_configurations_on_key", unique: true
  end

  create_table "budget_periods", force: :cascade do |t|
    t.bigint "account_id", null: false
    t.datetime "created_at", null: false
    t.date "end_date"
    t.string "name"
    t.string "period_type"
    t.date "start_date"
    t.decimal "total_amount", precision: 10, scale: 2
    t.datetime "updated_at", null: false
    t.index ["account_id"], name: "index_budget_periods_on_account_id"
  end

  create_table "career_carl_stories", force: :cascade do |t|
    t.text "action"
    t.text "behavioral_question", null: false
    t.bigint "career_profile_id", null: false
    t.text "context"
    t.datetime "created_at", null: false
    t.text "learning"
    t.text "result"
    t.datetime "updated_at", null: false
    t.index ["career_profile_id"], name: "index_career_carl_stories_on_career_profile_id"
  end

  create_table "career_companies", force: :cascade do |t|
    t.bigint "account_id", null: false
    t.datetime "created_at", null: false
    t.string "linkedin_url"
    t.string "name", null: false
    t.text "notes"
    t.datetime "updated_at", null: false
    t.string "website_url"
    t.index ["account_id", "name"], name: "index_career_companies_on_account_id_and_name"
    t.index ["account_id"], name: "index_career_companies_on_account_id"
  end

  create_table "career_events", force: :cascade do |t|
    t.bigint "account_id", null: false
    t.bigint "career_job_application_id", null: false
    t.datetime "created_at", null: false
    t.string "event_type", null: false
    t.jsonb "metadata", default: {}, null: false
    t.datetime "occurred_at", null: false
    t.datetime "updated_at", null: false
    t.index ["account_id", "event_type"], name: "index_career_events_on_account_id_and_event_type"
    t.index ["account_id"], name: "index_career_events_on_account_id"
    t.index ["career_job_application_id", "occurred_at"], name: "idx_on_career_job_application_id_occurred_at_c935b5682c"
    t.index ["career_job_application_id"], name: "index_career_events_on_career_job_application_id"
  end

  create_table "career_job_applications", force: :cascade do |t|
    t.bigint "account_id", null: false
    t.date "applied_on"
    t.bigint "career_company_id", null: false
    t.datetime "created_at", null: false
    t.string "currency", default: "USD", null: false
    t.integer "fit_score"
    t.date "found_on"
    t.text "job_description"
    t.text "job_url"
    t.string "location"
    t.text "notes"
    t.integer "priority", default: 0, null: false
    t.string "remote_type"
    t.string "role_title", null: false
    t.integer "salary_max"
    t.integer "salary_min"
    t.string "source"
    t.string "status", default: "saved", null: false
    t.datetime "updated_at", null: false
    t.index ["account_id", "applied_on"], name: "index_career_job_applications_on_account_id_and_applied_on"
    t.index ["account_id", "found_on"], name: "index_career_job_applications_on_account_id_and_found_on"
    t.index ["account_id", "status"], name: "index_career_job_applications_on_account_id_and_status"
    t.index ["account_id"], name: "index_career_job_applications_on_account_id"
    t.index ["career_company_id"], name: "index_career_job_applications_on_career_company_id"
  end

  create_table "career_profile_links", force: :cascade do |t|
    t.bigint "career_profile_id", null: false
    t.datetime "created_at", null: false
    t.string "name", null: false
    t.datetime "updated_at", null: false
    t.string "url", null: false
    t.index ["career_profile_id"], name: "index_career_profile_links_on_career_profile_id"
  end

  create_table "career_profiles", force: :cascade do |t|
    t.bigint "account_id", null: false
    t.text "bio"
    t.text "cover_letter_snippet"
    t.datetime "created_at", null: false
    t.text "elevator_pitch"
    t.string "email"
    t.string "github_url"
    t.string "headline"
    t.string "linkedin_url"
    t.string "location"
    t.text "notes"
    t.string "phone"
    t.string "resume_url"
    t.text "salary_preferences"
    t.text "unique_selling_point"
    t.datetime "updated_at", null: false
    t.string "website_url"
    t.index ["account_id"], name: "index_career_profiles_on_account_id", unique: true
  end

  create_table "categories", force: :cascade do |t|
    t.bigint "account_id", null: false
    t.datetime "created_at", null: false
    t.string "name"
    t.datetime "updated_at", null: false
    t.index ["account_id"], name: "index_categories_on_account_id"
  end

  create_table "doc_links", force: :cascade do |t|
    t.datetime "created_at", null: false
    t.bigint "doc_id", null: false
    t.bigint "link_id", null: false
    t.datetime "updated_at", null: false
    t.index ["doc_id", "link_id"], name: "index_doc_links_on_doc_id_and_link_id", unique: true
    t.index ["doc_id"], name: "index_doc_links_on_doc_id"
    t.index ["link_id"], name: "index_doc_links_on_link_id"
  end

  create_table "docs", force: :cascade do |t|
    t.bigint "account_id", null: false
    t.text "content"
    t.datetime "created_at", null: false
    t.string "doc_type", default: "note", null: false
    t.bigint "documentable_id"
    t.string "documentable_type"
    t.string "title", null: false
    t.datetime "updated_at", null: false
    t.string "url"
    t.index ["account_id", "title"], name: "index_docs_on_account_id_and_title", unique: true
    t.index ["account_id"], name: "index_docs_on_account_id"
    t.index ["documentable_type", "documentable_id"], name: "index_docs_on_documentable"
  end

  create_table "expenses", force: :cascade do |t|
    t.bigint "account_id", null: false
    t.decimal "amount", precision: 10, scale: 2
    t.bigint "budget_period_id", null: false
    t.bigint "category_id", null: false
    t.bigint "counterparty_financial_account_id"
    t.bigint "counterparty_financial_liability_id"
    t.datetime "created_at", null: false
    t.date "date"
    t.string "description"
    t.bigint "financial_account_id"
    t.bigint "financial_liability_id"
    t.bigint "income_event_id"
    t.bigint "loan_id"
    t.bigint "planned_expense_id"
    t.datetime "updated_at", null: false
    t.index ["account_id"], name: "index_expenses_on_account_id"
    t.index ["budget_period_id"], name: "index_expenses_on_budget_period_id"
    t.index ["category_id"], name: "index_expenses_on_category_id"
    t.index ["counterparty_financial_account_id"], name: "index_expenses_on_counterparty_financial_account_id"
    t.index ["counterparty_financial_liability_id"], name: "index_expenses_on_counterparty_financial_liability_id"
    t.index ["financial_account_id"], name: "index_expenses_on_financial_account_id"
    t.index ["financial_liability_id"], name: "index_expenses_on_financial_liability_id"
    t.index ["income_event_id"], name: "index_expenses_on_income_event_id"
    t.index ["loan_id"], name: "index_expenses_on_loan_id"
    t.index ["planned_expense_id"], name: "index_expenses_on_planned_expense_id"
  end

  create_table "financial_accounts", force: :cascade do |t|
    t.string "account_group", default: "asset", null: false
    t.bigint "account_id", null: false
    t.string "account_type", null: false
    t.datetime "archived_at"
    t.datetime "created_at", null: false
    t.decimal "credit_limit", precision: 12, scale: 2
    t.bigint "legacy_liability_id"
    t.string "name", null: false
    t.text "notes"
    t.decimal "opening_balance", precision: 12, scale: 2, default: "0.0", null: false
    t.string "status", default: "active", null: false
    t.datetime "updated_at", null: false
    t.index ["account_id", "account_group", "name"], name: "index_financial_accounts_on_group_and_name", unique: true
    t.index ["account_id", "account_group"], name: "index_financial_accounts_on_account_and_group"
    t.index ["account_id"], name: "index_financial_accounts_on_account_id"
    t.index ["legacy_liability_id"], name: "index_financial_accounts_on_legacy_liability_id", unique: true, where: "(legacy_liability_id IS NOT NULL)"
    t.index ["status"], name: "index_financial_accounts_on_status"
    t.check_constraint "account_group::text = 'asset'::text AND (account_type::text = ANY (ARRAY['debit'::character varying, 'checking'::character varying, 'savings'::character varying]::text[])) OR account_group::text = 'liability'::text AND (account_type::text = ANY (ARRAY['credit_card'::character varying, 'personal_credit'::character varying]::text[]))", name: "financial_accounts_type_matches_group"
    t.check_constraint "account_group::text = ANY (ARRAY['asset'::character varying, 'liability'::character varying]::text[])", name: "financial_accounts_valid_group"
  end

  create_table "financial_budget_allocations", force: :cascade do |t|
    t.bigint "account_id", null: false
    t.bigint "budget_period_id", null: false
    t.bigint "category_id", null: false
    t.datetime "created_at", null: false
    t.string "description"
    t.float "percentage_of_total"
    t.decimal "planned_amount", precision: 10, scale: 2
    t.datetime "updated_at", null: false
    t.index ["account_id"], name: "index_financial_budget_allocations_on_account_id"
    t.index ["budget_period_id"], name: "index_financial_budget_allocations_on_budget_period_id"
    t.index ["category_id"], name: "index_financial_budget_allocations_on_category_id"
    t.check_constraint "planned_amount > 0::numeric", name: "financial_budget_allocations_positive_amount"
  end

  create_table "financial_funding_sources", force: :cascade do |t|
    t.bigint "account_id", null: false
    t.datetime "created_at", null: false
    t.string "description", null: false
    t.decimal "expected_amount", precision: 12, scale: 2, null: false
    t.date "expected_date", null: false
    t.bigint "expected_destination_account_id"
    t.bigint "expected_destination_asset_id"
    t.bigint "expected_destination_liability_id"
    t.bigint "financial_loan_id"
    t.bigint "financial_plan_id", null: false
    t.string "kind", default: "income", null: false
    t.bigint "legacy_income_event_id"
    t.string "resolution", default: "pending", null: false
    t.datetime "updated_at", null: false
    t.index ["account_id"], name: "index_financial_funding_sources_on_account_id"
    t.index ["expected_destination_account_id"], name: "idx_on_expected_destination_account_id_bda17e9c97"
    t.index ["expected_destination_asset_id"], name: "idx_on_expected_destination_asset_id_e22fd2d6af"
    t.index ["expected_destination_liability_id"], name: "idx_on_expected_destination_liability_id_6d8c44a66a"
    t.index ["financial_loan_id"], name: "index_financial_funding_sources_on_financial_loan_id"
    t.index ["financial_plan_id"], name: "index_financial_funding_sources_on_financial_plan_id"
    t.index ["legacy_income_event_id"], name: "index_financial_funding_sources_on_legacy_income_event_id", unique: true
    t.check_constraint "resolution::text = ANY (ARRAY['pending'::character varying, 'received'::character varying, 'not_received'::character varying, 'cancelled'::character varying, 'closed_with_variance'::character varying]::text[])", name: "financial_funding_sources_valid_resolution"
  end

  create_table "financial_liabilities", force: :cascade do |t|
    t.bigint "account_id", null: false
    t.datetime "archived_at"
    t.datetime "created_at", null: false
    t.decimal "credit_limit", precision: 12, scale: 2
    t.string "liability_type", null: false
    t.string "name", null: false
    t.text "notes"
    t.decimal "opening_balance", precision: 12, scale: 2, default: "0.0", null: false
    t.string "status", default: "active", null: false
    t.datetime "updated_at", null: false
    t.index ["account_id", "name"], name: "index_financial_liabilities_on_account_id_and_name", unique: true
    t.index ["account_id"], name: "index_financial_liabilities_on_account_id"
    t.index ["status"], name: "index_financial_liabilities_on_status"
  end

  create_table "financial_loan_installments", force: :cascade do |t|
    t.bigint "account_id", null: false
    t.datetime "created_at", null: false
    t.date "due_date", null: false
    t.decimal "expected_amount", precision: 12, scale: 2, null: false
    t.decimal "expected_interest", precision: 12, scale: 2, default: "0.0", null: false
    t.decimal "expected_principal", precision: 12, scale: 2, default: "0.0", null: false
    t.bigint "financial_loan_id", null: false
    t.integer "installment_number", null: false
    t.bigint "interest_entry_id"
    t.bigint "legacy_loan_payment_schedule_id"
    t.bigint "payment_transaction_id"
    t.bigint "planned_transaction_id"
    t.string "resolution", default: "scheduled", null: false
    t.datetime "updated_at", null: false
    t.index ["account_id"], name: "index_financial_loan_installments_on_account_id"
    t.index ["financial_loan_id", "installment_number"], name: "index_loan_installments_on_number", unique: true
    t.index ["financial_loan_id"], name: "index_financial_loan_installments_on_financial_loan_id"
    t.index ["interest_entry_id"], name: "index_financial_loan_installments_on_interest_entry_id"
    t.index ["legacy_loan_payment_schedule_id"], name: "index_loan_installments_on_legacy_schedule", unique: true
    t.index ["payment_transaction_id"], name: "index_financial_loan_installments_on_payment_transaction_id"
    t.index ["planned_transaction_id"], name: "index_financial_loan_installments_on_planned_transaction_id"
  end

  create_table "financial_loans", force: :cascade do |t|
    t.bigint "account_id", null: false
    t.datetime "created_at", null: false
    t.bigint "destination_account_id"
    t.bigint "destination_asset_id"
    t.bigint "destination_liability_id"
    t.decimal "final_payment_amount", precision: 12, scale: 2
    t.bigint "interest_category_id"
    t.decimal "interest_rate"
    t.bigint "legacy_income_event_id"
    t.string "lender_name"
    t.bigint "liability_account_id"
    t.bigint "liability_id"
    t.string "lifecycle_status", default: "simulated", null: false
    t.string "name", null: false
    t.text "notes"
    t.integer "number_of_payments"
    t.decimal "payment_amount", precision: 12, scale: 2
    t.string "payment_frequency"
    t.decimal "principal_amount", precision: 12, scale: 2, null: false
    t.string "repayment_basis"
    t.datetime "updated_at", null: false
    t.index ["account_id"], name: "index_financial_loans_on_account_id"
    t.index ["destination_account_id"], name: "index_financial_loans_on_destination_account_id"
    t.index ["destination_asset_id"], name: "index_financial_loans_on_destination_asset_id"
    t.index ["destination_liability_id"], name: "index_financial_loans_on_destination_liability_id"
    t.index ["interest_category_id"], name: "index_financial_loans_on_interest_category_id"
    t.index ["legacy_income_event_id"], name: "index_financial_loans_on_legacy_income_event_id", unique: true
    t.index ["liability_account_id"], name: "index_financial_loans_on_liability_account_id"
    t.index ["liability_id"], name: "index_financial_loans_on_liability_id"
    t.check_constraint "lifecycle_status::text = ANY (ARRAY['simulated'::character varying, 'active'::character varying, 'paid'::character varying, 'cancelled'::character varying]::text[])", name: "financial_loans_valid_lifecycle"
  end

  create_table "financial_planned_transactions", force: :cascade do |t|
    t.bigint "account_id", null: false
    t.boolean "budget_consuming", null: false
    t.bigint "category_id"
    t.boolean "commits_plan_funds", default: false, null: false
    t.datetime "created_at", null: false
    t.string "description", null: false
    t.bigint "destination_account_id"
    t.bigint "destination_asset_id"
    t.date "due_date"
    t.string "execution_status", default: "pending", null: false
    t.string "importance", default: "normal", null: false
    t.string "kind", null: false
    t.bigint "legacy_planned_expense_id"
    t.bigint "liability_id"
    t.text "notes"
    t.bigint "origin_plan_id"
    t.bigint "plan_id"
    t.decimal "planned_amount", precision: 12, scale: 2, null: false
    t.date "planned_execution_date"
    t.integer "position"
    t.bigint "recurring_transaction_id"
    t.bigint "savings_goal_id"
    t.bigint "shopping_item_id"
    t.bigint "source_account_id"
    t.bigint "source_asset_id"
    t.datetime "updated_at", null: false
    t.index ["account_id", "execution_status"], name: "index_financial_planned_transactions_on_execution"
    t.index ["account_id"], name: "index_financial_planned_transactions_on_account_id"
    t.index ["category_id"], name: "index_financial_planned_transactions_on_category_id"
    t.index ["destination_account_id"], name: "index_financial_planned_transactions_on_destination_account_id"
    t.index ["destination_asset_id"], name: "index_financial_planned_transactions_on_destination_asset_id"
    t.index ["legacy_planned_expense_id"], name: "index_planned_transactions_on_legacy_expense", unique: true
    t.index ["liability_id"], name: "index_financial_planned_transactions_on_liability_id"
    t.index ["origin_plan_id"], name: "index_financial_planned_transactions_on_origin_plan_id"
    t.index ["plan_id", "position"], name: "index_financial_planned_transactions_on_position", unique: true, where: "(plan_id IS NOT NULL)"
    t.index ["plan_id"], name: "index_financial_planned_transactions_on_plan_id"
    t.index ["recurring_transaction_id"], name: "idx_on_recurring_transaction_id_2fdf0b3916"
    t.index ["savings_goal_id"], name: "index_financial_planned_transactions_on_savings_goal_id"
    t.index ["shopping_item_id"], name: "index_financial_planned_transactions_on_shopping_item_id"
    t.index ["source_account_id"], name: "index_financial_planned_transactions_on_source_account_id"
    t.index ["source_asset_id"], name: "index_financial_planned_transactions_on_source_asset_id"
    t.check_constraint "execution_status::text = ANY (ARRAY['pending'::character varying, 'applied'::character varying, 'cancelled'::character varying, 'skipped'::character varying]::text[])", name: "financial_planned_transactions_valid_execution"
  end

  create_table "financial_plans", force: :cascade do |t|
    t.bigint "account_id", null: false
    t.decimal "actual_ending_balance_at_close", precision: 12, scale: 2
    t.bigint "budget_period_id"
    t.datetime "closed_at"
    t.datetime "created_at", null: false
    t.bigint "legacy_income_event_id"
    t.string "lifecycle_status", default: "active", null: false
    t.string "name", null: false
    t.text "notes"
    t.date "planned_for", null: false
    t.datetime "updated_at", null: false
    t.index ["account_id", "planned_for", "id"], name: "index_financial_plans_on_chronology"
    t.index ["account_id"], name: "index_financial_plans_on_account_id"
    t.index ["budget_period_id"], name: "index_financial_plans_on_budget_period_id"
    t.index ["legacy_income_event_id"], name: "index_financial_plans_on_legacy_income_event_id", unique: true
    t.check_constraint "lifecycle_status::text = ANY (ARRAY['draft'::character varying, 'active'::character varying, 'closed'::character varying, 'cancelled'::character varying]::text[])", name: "financial_plans_valid_lifecycle"
  end

  create_table "financial_recurring_transactions", force: :cascade do |t|
    t.bigint "account_id", null: false
    t.decimal "amount", precision: 12, scale: 2, null: false
    t.boolean "budget_consuming", null: false
    t.bigint "category_id"
    t.datetime "created_at", null: false
    t.string "description"
    t.bigint "destination_account_id"
    t.string "frequency", null: false
    t.string "importance", default: "normal", null: false
    t.string "name", null: false
    t.text "notes"
    t.bigint "source_account_id"
    t.string "status", default: "active", null: false
    t.string "transaction_kind", null: false
    t.datetime "updated_at", null: false
    t.index ["account_id", "status", "name"], name: "index_financial_recurring_transactions_for_picker"
    t.index ["account_id"], name: "index_financial_recurring_transactions_on_account_id"
    t.index ["category_id"], name: "index_financial_recurring_transactions_on_category_id"
    t.index ["destination_account_id"], name: "idx_on_destination_account_id_e6e08c5369"
    t.index ["source_account_id"], name: "index_financial_recurring_transactions_on_source_account_id"
    t.check_constraint "amount > 0::numeric", name: "financial_recurring_transactions_positive_amount"
    t.check_constraint "frequency::text = ANY (ARRAY['weekly'::character varying, 'biweekly'::character varying, 'quincenal'::character varying, 'monthly'::character varying, 'bimonthly'::character varying, 'quarterly'::character varying, 'custom'::character varying]::text[])", name: "financial_recurring_transactions_valid_frequency"
    t.check_constraint "importance::text = ANY (ARRAY['low'::character varying, 'normal'::character varying, 'high'::character varying, 'essential'::character varying]::text[])", name: "financial_recurring_transactions_valid_importance"
    t.check_constraint "source_account_id IS NULL OR destination_account_id IS NULL OR source_account_id <> destination_account_id", name: "financial_recurring_transactions_distinct_accounts"
    t.check_constraint "status::text = ANY (ARRAY['active'::character varying, 'archived'::character varying]::text[])", name: "financial_recurring_transactions_valid_status"
    t.check_constraint "transaction_kind::text = ANY (ARRAY['outflow'::character varying, 'liability_charge'::character varying, 'transfer'::character varying, 'liability_payment'::character varying]::text[])", name: "financial_recurring_transactions_valid_kind"
  end

  create_table "financial_savings_goals", force: :cascade do |t|
    t.bigint "account_id", null: false
    t.bigint "category_id", null: false
    t.datetime "created_at", null: false
    t.string "description"
    t.string "frequency", null: false
    t.string "name", null: false
    t.text "notes"
    t.decimal "total_amount", precision: 10, scale: 2, null: false
    t.datetime "updated_at", null: false
    t.index ["account_id"], name: "index_financial_savings_goals_on_account_id"
    t.index ["category_id"], name: "index_financial_savings_goals_on_category_id"
    t.check_constraint "total_amount > 0::numeric", name: "financial_savings_goals_positive_amount"
  end

  create_table "financial_transactions", force: :cascade do |t|
    t.bigint "account_id", null: false
    t.decimal "amount", precision: 12, scale: 2, null: false
    t.bigint "budget_period_id"
    t.bigint "category_id"
    t.bigint "counterparty_financial_account_id"
    t.bigint "counterparty_financial_liability_id"
    t.datetime "created_at", null: false
    t.string "description", null: false
    t.bigint "destination_account_id"
    t.bigint "expense_id"
    t.bigint "financial_account_id"
    t.bigint "financial_liability_id"
    t.bigint "financial_loan_id"
    t.bigint "funding_source_id"
    t.bigint "income_event_id"
    t.time "entry_time"
    t.text "notes"
    t.bigint "plan_id"
    t.bigint "planned_expense_id"
    t.bigint "planned_transaction_id"
    t.datetime "reconciled_at"
    t.bigint "source_account_id"
    t.date "transaction_date", null: false
    t.string "transaction_type", null: false
    t.datetime "updated_at", null: false
    t.index ["account_id", "reconciled_at"], name: "index_financial_transactions_on_reconciliation"
    t.index ["account_id", "transaction_date"], name: "idx_on_account_id_transaction_date_ec4024adbf"
    t.index ["account_id"], name: "index_financial_transactions_on_account_id"
    t.index ["budget_period_id"], name: "index_financial_transactions_on_budget_period_id"
    t.index ["category_id"], name: "index_financial_transactions_on_category_id"
    t.index ["counterparty_financial_account_id"], name: "idx_on_counterparty_financial_account_id_0c27cdac8f"
    t.index ["counterparty_financial_liability_id"], name: "idx_on_counterparty_financial_liability_id_e34a63eb26"
    t.index ["destination_account_id"], name: "index_financial_transactions_on_destination_account_id"
    t.index ["expense_id"], name: "index_financial_transactions_on_expense_id"
    t.index ["financial_account_id"], name: "index_financial_transactions_on_financial_account_id"
    t.index ["financial_liability_id"], name: "index_financial_transactions_on_financial_liability_id"
    t.index ["financial_loan_id"], name: "index_financial_transactions_on_financial_loan_id"
    t.index ["financial_loan_id"], name: "index_financial_transactions_on_unique_loan_disbursement", unique: true, where: "((financial_loan_id IS NOT NULL) AND ((transaction_type)::text = 'loan_disbursement'::text))"
    t.index ["funding_source_id"], name: "index_financial_entries_on_unique_funding_source", unique: true, where: "(funding_source_id IS NOT NULL)"
    t.index ["funding_source_id"], name: "index_financial_transactions_on_funding_source_id"
    t.index ["income_event_id"], name: "index_financial_transactions_on_income_event_id"
    t.index ["plan_id"], name: "index_financial_transactions_on_plan_id"
    t.index ["planned_expense_id"], name: "index_financial_entries_on_unique_planned_expense", unique: true, where: "(planned_expense_id IS NOT NULL)"
    t.index ["planned_expense_id"], name: "index_financial_transactions_on_planned_expense_id"
    t.index ["planned_transaction_id"], name: "index_financial_entries_on_unique_planned_transaction", unique: true, where: "(planned_transaction_id IS NOT NULL)"
    t.index ["planned_transaction_id"], name: "index_financial_transactions_on_planned_transaction_id"
    t.index ["source_account_id"], name: "index_financial_transactions_on_source_account_id"
    t.index ["transaction_type"], name: "index_financial_transactions_on_transaction_type"
    t.check_constraint "source_account_id IS NULL OR destination_account_id IS NULL OR source_account_id <> destination_account_id", name: "financial_transactions_distinct_accounts"
    t.check_constraint "transaction_type::text = ANY (ARRAY['income'::character varying, 'expense'::character varying, 'transfer'::character varying, 'debt_payment'::character varying, 'loan_disbursement'::character varying, 'adjustment'::character varying, 'refund'::character varying]::text[])", name: "financial_transactions_valid_type"
  end

  create_table "income_events", force: :cascade do |t|
    t.bigint "account_id", null: false
    t.decimal "actual_ending_balance_at_close", precision: 12, scale: 2
    t.bigint "budget_period_id"
    t.datetime "closed_at"
    t.datetime "created_at", null: false
    t.string "description", null: false
    t.decimal "expected_amount", precision: 10, scale: 2, null: false
    t.date "expected_date", null: false
    t.string "income_type", default: "regular", null: false
    t.decimal "interest_rate", precision: 6, scale: 3
    t.boolean "interest_rate_estimated", default: false, null: false
    t.string "lender_name"
    t.string "lifecycle_status", default: "active", null: false
    t.decimal "loan_amount", precision: 10, scale: 2
    t.bigint "loan_disbursement_destination_asset_id"
    t.bigint "loan_disbursement_destination_liability_id"
    t.bigint "loan_liability_id"
    t.text "notes"
    t.integer "number_of_payments"
    t.decimal "payment_amount", precision: 10, scale: 2
    t.string "payment_frequency"
    t.decimal "received_amount", precision: 10, scale: 2
    t.date "received_date"
    t.bigint "regular_income_destination_asset_id"
    t.bigint "regular_income_destination_liability_id"
    t.string "status", default: "pending", null: false
    t.datetime "updated_at", null: false
    t.index ["account_id", "expected_date", "id"], name: "index_income_events_on_plan_chronology"
    t.index ["account_id"], name: "index_income_events_on_account_id"
    t.index ["budget_period_id"], name: "index_income_events_on_budget_period_id"
    t.index ["income_type"], name: "index_income_events_on_income_type"
    t.index ["loan_disbursement_destination_asset_id"], name: "index_income_events_on_loan_disbursement_destination_asset_id"
    t.index ["loan_disbursement_destination_liability_id"], name: "idx_on_loan_disbursement_destination_liability_id_df03d3d9ae"
    t.index ["loan_liability_id"], name: "index_income_events_on_loan_liability_id"
    t.index ["regular_income_destination_asset_id"], name: "index_income_events_on_regular_income_destination_asset_id"
    t.index ["regular_income_destination_liability_id"], name: "index_income_events_on_regular_income_destination_liability_id"
  end

  create_table "inventory_items", force: :cascade do |t|
    t.bigint "account_id", null: false
    t.bigint "category_id"
    t.boolean "consumable", default: true, null: false
    t.datetime "created_at", null: false
    t.string "name", null: false
    t.text "notes"
    t.string "stock_state", default: "in_stock", null: false
    t.datetime "updated_at", null: false
    t.index ["account_id"], name: "index_inventory_items_on_account_id"
    t.index ["category_id"], name: "index_inventory_items_on_category_id"
    t.index ["consumable"], name: "index_inventory_items_on_consumable"
    t.index ["stock_state"], name: "index_inventory_items_on_stock_state"
  end

  create_table "links", force: :cascade do |t|
    t.bigint "account_id", null: false
    t.datetime "created_at", null: false
    t.text "description"
    t.string "link_type", default: "reference", null: false
    t.string "title", null: false
    t.datetime "updated_at", null: false
    t.string "url", null: false
    t.index ["account_id", "url"], name: "index_links_on_account_id_and_url", unique: true
    t.index ["account_id"], name: "index_links_on_account_id"
  end

  create_table "loan_payment_schedules", force: :cascade do |t|
    t.bigint "account_id", null: false
    t.decimal "amount", precision: 10, scale: 2, null: false
    t.datetime "created_at", null: false
    t.date "due_date", null: false
    t.integer "installment_number", null: false
    t.decimal "interest_amount", precision: 10, scale: 2, default: "0.0", null: false
    t.bigint "loan_id", null: false
    t.date "paid_at"
    t.decimal "principal_amount", precision: 10, scale: 2, default: "0.0", null: false
    t.string "status", default: "scheduled", null: false
    t.datetime "updated_at", null: false
    t.index ["account_id"], name: "index_loan_payment_schedules_on_account_id"
    t.index ["loan_id", "due_date"], name: "index_loan_payment_schedules_on_loan_id_and_due_date"
    t.index ["loan_id", "installment_number"], name: "index_loan_payment_schedules_on_loan_id_and_installment_number", unique: true
    t.index ["loan_id"], name: "index_loan_payment_schedules_on_loan_id"
    t.index ["status"], name: "index_loan_payment_schedules_on_status"
  end

  create_table "meetings", force: :cascade do |t|
    t.bigint "account_id", null: false
    t.datetime "created_at", null: false
    t.text "description"
    t.datetime "end_time"
    t.string "location"
    t.string "meeting_url"
    t.bigint "meetingable_id"
    t.string "meetingable_type"
    t.datetime "start_time", null: false
    t.string "title", null: false
    t.datetime "updated_at", null: false
    t.index ["account_id", "title"], name: "index_meetings_on_account_id_and_title"
    t.index ["account_id"], name: "index_meetings_on_account_id"
    t.index ["meetingable_type", "meetingable_id"], name: "index_meetings_on_meetingable"
    t.index ["start_time"], name: "index_meetings_on_start_time"
  end

  create_table "planned_expenses", force: :cascade do |t|
    t.bigint "account_id", null: false
    t.decimal "amount", precision: 10, scale: 2, null: false
    t.date "applied_on"
    t.bigint "category_id"
    t.boolean "commits_plan_funds", default: false, null: false
    t.bigint "counterparty_financial_account_id"
    t.datetime "created_at", null: false
    t.string "description", null: false
    t.date "due_date"
    t.string "execution_status", default: "pending", null: false
    t.bigint "expense_template_id"
    t.bigint "financial_account_id"
    t.bigint "financial_liability_id"
    t.string "importance", default: "normal", null: false
    t.bigint "income_event_id"
    t.string "kind", null: false
    t.integer "loan_installment_number"
    t.text "notes"
    t.bigint "origin_income_event_id"
    t.date "planned_for"
    t.integer "position"
    t.bigint "shopping_item_id"
    t.string "status", null: false
    t.datetime "updated_at", null: false
    t.index ["account_id", "execution_status"], name: "index_planned_transactions_on_execution_status"
    t.index ["account_id"], name: "index_planned_expenses_on_account_id"
    t.index ["applied_on"], name: "index_planned_expenses_on_applied_on"
    t.index ["category_id"], name: "index_planned_expenses_on_category_id"
    t.index ["counterparty_financial_account_id"], name: "index_planned_expenses_on_counterparty_financial_account_id"
    t.index ["expense_template_id"], name: "index_planned_expenses_on_expense_template_id"
    t.index ["financial_account_id"], name: "index_planned_expenses_on_financial_account_id"
    t.index ["financial_liability_id"], name: "index_planned_expenses_on_financial_liability_id"
    t.index ["income_event_id", "loan_installment_number"], name: "index_planned_expenses_on_income_event_and_loan_installment", unique: true, where: "((loan_installment_number IS NOT NULL) AND (origin_income_event_id IS NULL))"
    t.index ["income_event_id", "position"], name: "index_planned_transactions_on_plan_position", unique: true, where: "(income_event_id IS NOT NULL)"
    t.index ["income_event_id"], name: "index_planned_expenses_on_income_event_id"
    t.index ["origin_income_event_id", "loan_installment_number"], name: "idx_planned_expenses_on_origin_event_installment", unique: true, where: "((loan_installment_number IS NOT NULL) AND (origin_income_event_id IS NOT NULL))"
    t.index ["origin_income_event_id"], name: "index_planned_expenses_on_origin_income_event_id"
    t.index ["shopping_item_id"], name: "index_planned_expenses_on_shopping_item_id"
  end

  create_table "project_docs", force: :cascade do |t|
    t.datetime "created_at", null: false
    t.bigint "doc_id", null: false
    t.bigint "project_id", null: false
    t.datetime "updated_at", null: false
    t.index ["doc_id"], name: "index_project_docs_on_doc_id"
    t.index ["project_id", "doc_id"], name: "index_project_docs_on_project_id_and_doc_id", unique: true
    t.index ["project_id"], name: "index_project_docs_on_project_id"
  end

  create_table "project_links", force: :cascade do |t|
    t.datetime "created_at", null: false
    t.bigint "link_id", null: false
    t.bigint "project_id", null: false
    t.datetime "updated_at", null: false
    t.index ["link_id"], name: "index_project_links_on_link_id"
    t.index ["project_id", "link_id"], name: "index_project_links_on_project_id_and_link_id", unique: true
    t.index ["project_id"], name: "index_project_links_on_project_id"
  end

  create_table "project_meetings", force: :cascade do |t|
    t.datetime "created_at", null: false
    t.bigint "meeting_id", null: false
    t.bigint "project_id", null: false
    t.datetime "updated_at", null: false
    t.index ["meeting_id"], name: "index_project_meetings_on_meeting_id"
    t.index ["project_id", "meeting_id"], name: "index_project_meetings_on_project_id_and_meeting_id", unique: true
    t.index ["project_id"], name: "index_project_meetings_on_project_id"
  end

  create_table "projects", force: :cascade do |t|
    t.bigint "account_id", null: false
    t.datetime "created_at", null: false
    t.date "end_date"
    t.string "name", null: false
    t.bigint "owner_id", null: false
    t.string "priority", default: "medium", null: false
    t.date "start_date"
    t.string "status", default: "pending", null: false
    t.text "summary"
    t.datetime "updated_at", null: false
    t.index ["account_id", "name"], name: "index_projects_on_account_id_and_name", unique: true
    t.index ["account_id"], name: "index_projects_on_account_id"
  end

  create_table "recurring_tasks", force: :cascade do |t|
    t.bigint "account_id", null: false
    t.datetime "created_at", null: false
    t.datetime "last_done_at"
    t.string "name", null: false
    t.date "next_due_date"
    t.text "notes"
    t.integer "position"
    t.string "recurrence", default: "none", null: false
    t.bigint "task_area_id"
    t.datetime "updated_at", null: false
    t.index ["account_id"], name: "index_recurring_tasks_on_account_id"
    t.index ["task_area_id"], name: "index_recurring_tasks_on_task_area_id"
  end

  create_table "reporting_conversations", force: :cascade do |t|
    t.bigint "account_id", null: false
    t.bigint "account_membership_id", null: false
    t.datetime "created_at", null: false
    t.date "date_from", null: false
    t.date "date_to", null: false
    t.string "title", null: false
    t.integer "turns_count", default: 0, null: false
    t.datetime "updated_at", null: false
    t.index ["account_id"], name: "index_reporting_conversations_on_account_id"
    t.index ["account_membership_id", "updated_at"], name: "idx_on_account_membership_id_updated_at_2ea686a3eb"
    t.index ["account_membership_id"], name: "index_reporting_conversations_on_account_membership_id"
  end

  create_table "reporting_turns", force: :cascade do |t|
    t.text "answer"
    t.bigint "conversation_id", null: false
    t.datetime "created_at", null: false
    t.string "error_code"
    t.text "error_message"
    t.string "model"
    t.datetime "processing_started_at"
    t.string "provider_response_id"
    t.text "question", null: false
    t.string "status", default: "queued", null: false
    t.datetime "updated_at", null: false
    t.index ["conversation_id"], name: "index_reporting_turns_on_conversation_id"
    t.index ["status", "created_at"], name: "index_reporting_turns_on_status_and_created_at"
  end

  create_table "reporting_usage_events", force: :cascade do |t|
    t.bigint "account_id", null: false
    t.bigint "account_membership_id"
    t.integer "cached_input_tokens", default: 0, null: false
    t.bigint "conversation_id"
    t.datetime "created_at", null: false
    t.string "error_code"
    t.integer "input_tokens", default: 0, null: false
    t.string "model", null: false
    t.integer "output_tokens", default: 0, null: false
    t.datetime "provider_called_at"
    t.string "provider_response_id"
    t.string "status", default: "reserved", null: false
    t.bigint "turn_id"
    t.datetime "updated_at", null: false
    t.bigint "user_id", null: false
    t.index ["account_id"], name: "index_reporting_usage_events_on_account_id"
    t.index ["account_membership_id", "created_at"], name: "idx_reporting_usage_membership_month"
    t.index ["account_membership_id"], name: "index_reporting_usage_events_on_account_membership_id"
    t.index ["conversation_id"], name: "index_reporting_usage_events_on_conversation_id"
    t.index ["turn_id"], name: "index_reporting_usage_events_on_turn_id"
    t.index ["user_id"], name: "index_reporting_usage_events_on_user_id"
  end

  create_table "sessions", force: :cascade do |t|
    t.datetime "created_at", null: false
    t.string "ip_address"
    t.datetime "updated_at", null: false
    t.string "user_agent"
    t.bigint "user_id", null: false
    t.index ["user_id"], name: "index_sessions_on_user_id"
  end

  create_table "shopping_items", force: :cascade do |t|
    t.bigint "account_id", null: false
    t.bigint "category_id"
    t.datetime "created_at", null: false
    t.decimal "estimated_amount", precision: 10, scale: 2
    t.bigint "expense_id"
    t.bigint "financial_transaction_id"
    t.string "frequency"
    t.string "item_type", default: "one_time", null: false
    t.date "last_purchased_at"
    t.string "name", null: false
    t.text "notes"
    t.bigint "planned_expense_id"
    t.bigint "planned_transaction_id"
    t.string "quantity"
    t.string "status", default: "pending", null: false
    t.datetime "updated_at", null: false
    t.index ["account_id"], name: "index_shopping_items_on_account_id"
    t.index ["category_id"], name: "index_shopping_items_on_category_id"
    t.index ["expense_id"], name: "index_shopping_items_on_expense_id"
    t.index ["financial_transaction_id"], name: "index_shopping_items_on_financial_transaction_id"
    t.index ["item_type"], name: "index_shopping_items_on_item_type"
    t.index ["planned_expense_id"], name: "index_shopping_items_on_planned_expense_id"
    t.index ["planned_transaction_id"], name: "index_shopping_items_on_planned_transaction_id"
    t.index ["status"], name: "index_shopping_items_on_status"
  end

  create_table "task_areas", force: :cascade do |t|
    t.bigint "account_id", null: false
    t.datetime "created_at", null: false
    t.string "name", null: false
    t.datetime "updated_at", null: false
    t.index ["account_id", "name"], name: "index_task_areas_on_account_id_and_name", unique: true
    t.index ["account_id"], name: "index_task_areas_on_account_id"
  end

  create_table "tasks", force: :cascade do |t|
    t.bigint "account_id", null: false
    t.datetime "completed_at"
    t.datetime "created_at", null: false
    t.text "description"
    t.date "due_date"
    t.jsonb "metadata", default: {}, null: false
    t.bigint "owner_id", null: false
    t.string "priority", default: "medium", null: false
    t.bigint "project_id"
    t.string "status", default: "backlog", null: false
    t.string "task_number", null: false
    t.bigint "taskable_id"
    t.string "taskable_type"
    t.string "title", null: false
    t.datetime "updated_at", null: false
    t.index ["account_id", "task_number"], name: "index_tasks_on_account_id_and_task_number", unique: true
    t.index ["account_id"], name: "index_tasks_on_account_id"
    t.index ["metadata"], name: "index_tasks_on_metadata", using: :gin
    t.index ["priority"], name: "index_tasks_on_priority"
    t.index ["project_id", "task_number"], name: "index_tasks_on_project_id_and_task_number", unique: true
    t.index ["project_id"], name: "index_tasks_on_project_id"
    t.index ["status"], name: "index_tasks_on_status"
    t.index ["taskable_type", "taskable_id"], name: "index_tasks_on_taskable"
  end

  create_table "users", force: :cascade do |t|
    t.datetime "created_at", null: false
    t.string "email_address", null: false
    t.string "locale", default: "en"
    t.string "name", null: false
    t.string "password_digest", null: false
    t.boolean "system_admin", default: false, null: false
    t.string "theme_palette", default: "executive-calm", null: false
    t.datetime "updated_at", null: false
    t.index ["email_address"], name: "index_users_on_email_address", unique: true
  end

  add_foreign_key "account_memberships", "accounts"
  add_foreign_key "account_memberships", "users"
  add_foreign_key "budget_periods", "accounts"
  add_foreign_key "career_carl_stories", "career_profiles"
  add_foreign_key "career_companies", "accounts"
  add_foreign_key "career_events", "accounts"
  add_foreign_key "career_events", "career_job_applications"
  add_foreign_key "career_job_applications", "accounts"
  add_foreign_key "career_job_applications", "career_companies"
  add_foreign_key "career_profile_links", "career_profiles"
  add_foreign_key "career_profiles", "accounts"
  add_foreign_key "categories", "accounts"
  add_foreign_key "doc_links", "docs"
  add_foreign_key "doc_links", "links"
  add_foreign_key "docs", "accounts"
  add_foreign_key "expenses", "accounts"
  add_foreign_key "expenses", "budget_periods"
  add_foreign_key "expenses", "categories"
  add_foreign_key "expenses", "financial_accounts"
  add_foreign_key "expenses", "financial_accounts", column: "counterparty_financial_account_id"
  add_foreign_key "expenses", "financial_accounts", column: "counterparty_financial_liability_id"
  add_foreign_key "expenses", "financial_accounts", column: "financial_liability_id"
  add_foreign_key "expenses", "income_events"
  add_foreign_key "expenses", "income_events", column: "loan_id"
  add_foreign_key "expenses", "planned_expenses"
  add_foreign_key "financial_accounts", "accounts"
  add_foreign_key "financial_budget_allocations", "accounts"
  add_foreign_key "financial_budget_allocations", "budget_periods"
  add_foreign_key "financial_budget_allocations", "categories"
  add_foreign_key "financial_funding_sources", "accounts"
  add_foreign_key "financial_funding_sources", "financial_accounts", column: "expected_destination_account_id"
  add_foreign_key "financial_funding_sources", "financial_accounts", column: "expected_destination_asset_id"
  add_foreign_key "financial_funding_sources", "financial_accounts", column: "expected_destination_liability_id"
  add_foreign_key "financial_funding_sources", "financial_loans"
  add_foreign_key "financial_funding_sources", "financial_plans"
  add_foreign_key "financial_liabilities", "accounts"
  add_foreign_key "financial_loan_installments", "accounts"
  add_foreign_key "financial_loan_installments", "financial_transactions", column: "interest_entry_id"
  add_foreign_key "financial_loan_installments", "financial_loans"
  add_foreign_key "financial_loan_installments", "financial_planned_transactions", column: "planned_transaction_id"
  add_foreign_key "financial_loan_installments", "financial_transactions", column: "payment_transaction_id"
  add_foreign_key "financial_loans", "accounts"
  add_foreign_key "financial_loans", "categories", column: "interest_category_id"
  add_foreign_key "financial_loans", "financial_accounts", column: "destination_account_id"
  add_foreign_key "financial_loans", "financial_accounts", column: "destination_asset_id"
  add_foreign_key "financial_loans", "financial_accounts", column: "destination_liability_id"
  add_foreign_key "financial_loans", "financial_accounts", column: "liability_account_id"
  add_foreign_key "financial_loans", "financial_accounts", column: "liability_id"
  add_foreign_key "financial_planned_transactions", "accounts"
  add_foreign_key "financial_planned_transactions", "categories"
  add_foreign_key "financial_planned_transactions", "financial_accounts", column: "destination_account_id"
  add_foreign_key "financial_planned_transactions", "financial_accounts", column: "destination_asset_id"
  add_foreign_key "financial_planned_transactions", "financial_accounts", column: "liability_id"
  add_foreign_key "financial_planned_transactions", "financial_accounts", column: "source_account_id"
  add_foreign_key "financial_planned_transactions", "financial_accounts", column: "source_asset_id"
  add_foreign_key "financial_planned_transactions", "financial_plans", column: "origin_plan_id"
  add_foreign_key "financial_planned_transactions", "financial_plans", column: "plan_id"
  add_foreign_key "financial_planned_transactions", "financial_recurring_transactions", column: "recurring_transaction_id"
  add_foreign_key "financial_planned_transactions", "financial_savings_goals", column: "savings_goal_id"
  add_foreign_key "financial_planned_transactions", "shopping_items"
  add_foreign_key "financial_plans", "accounts"
  add_foreign_key "financial_plans", "budget_periods"
  add_foreign_key "financial_recurring_transactions", "accounts"
  add_foreign_key "financial_recurring_transactions", "categories"
  add_foreign_key "financial_recurring_transactions", "financial_accounts", column: "destination_account_id"
  add_foreign_key "financial_recurring_transactions", "financial_accounts", column: "source_account_id"
  add_foreign_key "financial_savings_goals", "accounts"
  add_foreign_key "financial_savings_goals", "categories"
  add_foreign_key "financial_transactions", "accounts"
  add_foreign_key "financial_transactions", "budget_periods"
  add_foreign_key "financial_transactions", "categories"
  add_foreign_key "financial_transactions", "expenses"
  add_foreign_key "financial_transactions", "financial_accounts"
  add_foreign_key "financial_transactions", "financial_accounts", column: "counterparty_financial_account_id"
  add_foreign_key "financial_transactions", "financial_accounts", column: "counterparty_financial_liability_id"
  add_foreign_key "financial_transactions", "financial_accounts", column: "destination_account_id"
  add_foreign_key "financial_transactions", "financial_accounts", column: "financial_liability_id"
  add_foreign_key "financial_transactions", "financial_accounts", column: "source_account_id"
  add_foreign_key "financial_transactions", "financial_funding_sources", column: "funding_source_id"
  add_foreign_key "financial_transactions", "financial_loans"
  add_foreign_key "financial_transactions", "financial_planned_transactions", column: "planned_transaction_id"
  add_foreign_key "financial_transactions", "financial_plans", column: "plan_id"
  add_foreign_key "financial_transactions", "income_events"
  add_foreign_key "financial_transactions", "planned_expenses"
  add_foreign_key "income_events", "accounts"
  add_foreign_key "income_events", "budget_periods"
  add_foreign_key "income_events", "financial_accounts", column: "loan_disbursement_destination_asset_id"
  add_foreign_key "income_events", "financial_accounts", column: "loan_disbursement_destination_liability_id"
  add_foreign_key "income_events", "financial_accounts", column: "loan_liability_id"
  add_foreign_key "income_events", "financial_accounts", column: "regular_income_destination_asset_id"
  add_foreign_key "income_events", "financial_accounts", column: "regular_income_destination_liability_id"
  add_foreign_key "inventory_items", "accounts"
  add_foreign_key "inventory_items", "categories"
  add_foreign_key "links", "accounts"
  add_foreign_key "loan_payment_schedules", "accounts"
  add_foreign_key "loan_payment_schedules", "income_events", column: "loan_id"
  add_foreign_key "meetings", "accounts"
  add_foreign_key "planned_expenses", "accounts"
  add_foreign_key "planned_expenses", "categories"
  add_foreign_key "planned_expenses", "financial_accounts"
  add_foreign_key "planned_expenses", "financial_accounts", column: "counterparty_financial_account_id"
  add_foreign_key "planned_expenses", "financial_accounts", column: "financial_liability_id"
  add_foreign_key "planned_expenses", "financial_recurring_transactions", column: "expense_template_id"
  add_foreign_key "planned_expenses", "income_events"
  add_foreign_key "planned_expenses", "income_events", column: "origin_income_event_id"
  add_foreign_key "planned_expenses", "shopping_items"
  add_foreign_key "project_docs", "docs"
  add_foreign_key "project_docs", "projects"
  add_foreign_key "project_links", "links"
  add_foreign_key "project_links", "projects"
  add_foreign_key "project_meetings", "meetings"
  add_foreign_key "project_meetings", "projects"
  add_foreign_key "projects", "accounts"
  add_foreign_key "projects", "users", column: "owner_id"
  add_foreign_key "recurring_tasks", "accounts"
  add_foreign_key "recurring_tasks", "task_areas"
  add_foreign_key "reporting_conversations", "account_memberships"
  add_foreign_key "reporting_conversations", "accounts"
  add_foreign_key "reporting_turns", "reporting_conversations", column: "conversation_id"
  add_foreign_key "reporting_usage_events", "account_memberships", on_delete: :nullify
  add_foreign_key "reporting_usage_events", "accounts"
  add_foreign_key "reporting_usage_events", "reporting_conversations", column: "conversation_id", on_delete: :nullify
  add_foreign_key "reporting_usage_events", "reporting_turns", column: "turn_id", on_delete: :nullify
  add_foreign_key "reporting_usage_events", "users"
  add_foreign_key "sessions", "users"
  add_foreign_key "shopping_items", "accounts"
  add_foreign_key "shopping_items", "categories"
  add_foreign_key "shopping_items", "expenses"
  add_foreign_key "shopping_items", "financial_planned_transactions", column: "planned_transaction_id"
  add_foreign_key "shopping_items", "financial_transactions"
  add_foreign_key "shopping_items", "planned_expenses"
  add_foreign_key "task_areas", "accounts"
  add_foreign_key "tasks", "accounts"
  add_foreign_key "tasks", "projects"
  add_foreign_key "tasks", "users", column: "owner_id"
end
