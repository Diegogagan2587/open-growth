require "test_helper"

class FinancialPlanningAuditTest < ActiveSupport::TestCase
  test "reports planning and accounting inconsistencies without changing records" do
    account = Account.create!(name: "Audit household")
    Current.account = account
    plan = IncomeEvent.create!(account:, description: "Ambiguous receipt", expected_date: Date.new(2026, 8, 1), expected_amount: 100, status: "received")
    transaction = PlannedExpense.create!(account:, income_event: plan, category: Category.create!(account:, name: "Audit category"), description: "Missing execution", amount: 25, status: "paid")
    review_entry = Financial::Entry.create!(
      account:,
      entry_type: "outflow",
      entry_date: Date.current,
      amount: 10,
      description: "Review this entry",
      category: transaction.category,
      financial_account: Financial::Asset.create!(account:, name: "Audit asset", account_type: "checking", status: "active", opening_balance: 0),
      notes: "[Planning migration review required] Unlinked from planned transaction 123."
    )

    assert_no_changes -> { [ IncomeEvent.count, PlannedExpense.count, Financial::Entry.count ] } do
      report = FinancialPlanningAudit.call

      assert_includes report[:receipt_status_without_date_ids], plan.id
      assert_includes report[:final_transaction_without_entry_ids], transaction.id
      assert_includes report[:plan_without_funding_source_ids], plan.id
      assert_includes report[:planning_review_entry_ids], review_entry.id
    end
  ensure
    Current.account = nil
  end
end
