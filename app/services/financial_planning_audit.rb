class FinancialPlanningAudit
  def self.call
    new.call
  end

  def call
    {
      receipt_status_without_date_ids: IncomeEvent.where(status: %w[received applied], received_date: nil).ids,
      received_date_without_receipt_status_ids: IncomeEvent.where.not(received_date: nil).where.not(status: %w[received applied]).ids,
      regular_receipt_without_entry_ids: receipt_events_without_entry(IncomeEvent.regular, :regular_income_entry),
      loan_receipt_without_entry_ids: receipt_events_without_entry(IncomeEvent.loans, :loan_disbursement_entry),
      final_transaction_without_entry_ids: PlannedExpense.where(status: PlannedExpense::FINAL_STATUSES).left_joins(:financial_entry).where(financial_entries: { id: nil }).ids,
      transaction_without_position_ids: PlannedExpense.where.not(income_event_id: nil).where(position: nil).ids,
      duplicate_entry_transaction_ids: duplicate_ids(Financial::Entry.where.not(planned_expense_id: nil), :planned_expense_id),
      planning_review_entry_ids: Financial::Entry.where("notes LIKE ?", "%[Planning migration review required]%").ids,
      cross_account_budget_period_plan_ids: IncomeEvent.joins(:budget_period).where("income_events.account_id <> budget_periods.account_id").ids,
      cross_account_transaction_plan_ids: PlannedExpense.joins(:income_event).where("planned_expenses.account_id <> income_events.account_id").ids,
      legacy_expense_without_entry_ids: Expense.left_joins(:financial_entry).where(financial_entries: { id: nil }).ids,
      scheduled_installment_ids: LoanPaymentSchedule.scheduled.ids,
      plan_without_funding_source_ids: IncomeEvent.left_joins(:funding_sources).where(financial_funding_sources: { id: nil }).ids,
      resolved_funding_without_entry_ids: Financial::FundingSource.where(resolution: %w[received closed_with_variance]).left_joins(:receipt_entry).where(financial_entries: { id: nil }).ids,
      loan_without_borrowed_source_ids: Financial::Loan.left_joins(:funding_sources).where(financial_funding_sources: { id: nil }).ids,
      installment_without_planned_transaction_ids: Financial::LoanInstallment.where(planned_transaction_id: nil).ids,
      paid_installment_without_entry_ids: Financial::LoanInstallment.where(resolution: "paid", payment_entry_id: nil).ids
    }
  end

  private

  def receipt_events_without_entry(scope, association)
    scope.where(status: %w[received applied]).left_joins(association).where(financial_entries: { id: nil }).ids
  end

  def duplicate_ids(scope, column)
    scope.group(column).having("COUNT(*) > 1").count.keys
  end
end
