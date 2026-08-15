class FinancialPlanningAudit
  def self.call(account:, date_range: nil)
    new(account:, date_range:).call
  end

  def initialize(account:, date_range: nil)
    @account = account
    @date_range = date_range
  end

  def call
    {
      receipt_status_without_date_ids: income_events.where(status: %w[received applied], received_date: nil).ids,
      received_date_without_receipt_status_ids: income_events.where.not(received_date: nil).where.not(status: %w[received applied]).ids,
      regular_receipt_without_entry_ids: receipt_events_without_entry(income_events.regular, :regular_income_entry),
      loan_receipt_without_entry_ids: receipt_events_without_entry(income_events.loans, :loan_disbursement_entry),
      final_transaction_without_entry_ids: planned_expenses.where(status: PlannedExpense::FINAL_STATUSES).left_joins(:financial_entry).where(financial_entries: { id: nil }).ids,
      transaction_without_position_ids: planned_expenses.where.not(income_event_id: nil).where(position: nil).ids,
      duplicate_entry_transaction_ids: duplicate_ids(entries.where.not(planned_expense_id: nil), :planned_expense_id),
      planning_review_entry_ids: entries.where("notes LIKE ?", "%[Planning migration review required]%").ids,
      cross_account_budget_period_plan_ids: account.income_events.joins(:budget_period).where("income_events.account_id <> budget_periods.account_id").ids,
      cross_account_transaction_plan_ids: account.planned_expenses.joins(:income_event).where("planned_expenses.account_id <> income_events.account_id").ids,
      legacy_expense_without_entry_ids: expenses.left_joins(:financial_entry).where(financial_entries: { id: nil }).ids,
      scheduled_installment_ids: loan_payment_schedules.scheduled.ids,
      plan_without_funding_source_ids: income_events.left_joins(:funding_sources).where(financial_funding_sources: { id: nil }).ids,
      resolved_funding_without_entry_ids: funding_sources.where(resolution: %w[received closed_with_variance]).left_joins(:receipt_entry).where(financial_entries: { id: nil }).ids,
      loan_without_borrowed_source_ids: account.financial_loans.left_joins(:funding_sources).where(financial_funding_sources: { id: nil }).ids,
      installment_without_planned_transaction_ids: loan_installments.where(planned_transaction_id: nil).ids,
      paid_installment_without_entry_ids: loan_installments.where(resolution: "paid", payment_entry_id: nil).ids
    }
  end

  private

  attr_reader :account, :date_range

  def income_events
    @income_events ||= begin
      scope = account.income_events
      scope = scope.where(expected_date: date_range) if date_range
      scope
    end
  end

  def planned_expenses
    @planned_expenses ||= begin
      scope = account.planned_expenses
      scope = scope.where(due_date: date_range) if date_range
      scope
    end
  end

  def entries
    @entries ||= begin
      scope = account.financial_entries
      scope = scope.where(entry_date: date_range) if date_range
      scope
    end
  end

  def expenses
    @expenses ||= begin
      scope = account.expenses
      scope = scope.where(date: date_range) if date_range
      scope
    end
  end

  def funding_sources
    account.financial_funding_sources.joins(:financial_plan).merge(income_events)
  end

  def loan_installments
    scope = Financial::LoanInstallment.where(account: account)
    return scope unless date_range

    scope.where(due_date: date_range)
  end

  def loan_payment_schedules
    scope = LoanPaymentSchedule.where(account: account)
    return scope unless date_range

    scope.where(due_date: date_range)
  end

  def legacy_receipts_without_transaction(scope, transaction_type)
    scope.where(status: %w[received applied]).where.not(id: Financial::Transaction.where(transaction_type: transaction_type).select(:income_event_id)).ids
  end

  def duplicate_ids(scope, column)
    scope.group(column).having("COUNT(*) > 1").count.keys
  end
end
