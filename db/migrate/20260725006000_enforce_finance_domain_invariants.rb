class EnforceFinanceDomainInvariants < ActiveRecord::Migration[8.1]
  def change
    add_check_constraint :financial_accounts, "account_group IN ('asset', 'liability')", name: "financial_accounts_valid_group"
    add_check_constraint :financial_accounts, "(account_group = 'asset' AND account_type IN ('debit', 'checking', 'savings')) OR (account_group = 'liability' AND account_type IN ('credit_card', 'personal_credit'))", name: "financial_accounts_type_matches_group"
    add_check_constraint :financial_transactions, "transaction_type IN ('income', 'expense', 'transfer', 'debt_payment', 'loan_disbursement', 'adjustment', 'refund')", name: "financial_transactions_valid_type"
    add_check_constraint :financial_transactions, "source_account_id IS NULL OR destination_account_id IS NULL OR source_account_id <> destination_account_id", name: "financial_transactions_distinct_accounts"
    add_check_constraint :financial_plans, "lifecycle_status IN ('draft', 'active', 'closed', 'cancelled')", name: "financial_plans_valid_lifecycle"
    add_check_constraint :financial_planned_transactions, "execution_status IN ('pending', 'applied', 'cancelled', 'skipped')", name: "financial_planned_transactions_valid_execution"
    add_check_constraint :financial_funding_sources, "resolution IN ('pending', 'received', 'not_received', 'cancelled', 'closed_with_variance')", name: "financial_funding_sources_valid_resolution"
    add_check_constraint :financial_loans, "lifecycle_status IN ('simulated', 'active', 'paid', 'cancelled')", name: "financial_loans_valid_lifecycle"
    add_check_constraint :financial_budget_allocations, "planned_amount > 0", name: "financial_budget_allocations_positive_amount"
    add_check_constraint :financial_savings_goals, "total_amount > 0", name: "financial_savings_goals_positive_amount"
  end
end
