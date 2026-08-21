# frozen_string_literal: true

class Reporting::AnalysisSnapshot
  MAX_ENTRIES = 500

  def initialize(account:, date_range:)
    @account = account
    @date_range = date_range
  end

  def as_json(*)
    {
      period: { from: date_range.begin, to: date_range.end },
      totals_by_month: grouped_totals("DATE_TRUNC('month', transaction_date)"),
      totals_by_category: entries.left_joins(:category).group("categories.name").sum(:amount),
      totals_by_entry_type: entries.group(:transaction_type).sum(:amount),
      totals_by_financial_account: totals_by_financial_account,
      audit_findings: FinancialPlanningAudit.call(account:, date_range:),
      entries: selected_entries.map { |entry| serialize_entry(entry) },
      detail_truncated: entries.count > selected_entries.length,
      included_entry_count: selected_entries.length,
      total_entry_count: entries.count
    }
  end

  private

  attr_reader :account, :date_range

  def entries
    @entries ||= account.financial_transactions.where(transaction_date: date_range)
  end

  def grouped_totals(sql)
    entries.group(sql).order(Arel.sql(sql)).sum(:amount).transform_keys { |key| key.to_date.iso8601 }
  end

  def selected_entries
    @selected_entries ||= begin
      relation = entries.includes(:category, :financial_account, :counterparty_financial_account, :financial_liability)
      recent = relation.order(transaction_date: :desc, entry_time: :desc, id: :desc).limit(MAX_ENTRIES / 2).to_a
      largest = relation.order(amount: :desc, id: :desc).limit(MAX_ENTRIES / 2).to_a
      (recent + largest).uniq(&:id).first(MAX_ENTRIES)
    end
  end

  def totals_by_financial_account
    period_entries = entries.to_a
    account.financial_accounts.order(:name).to_h do |financial_account|
      delta = period_entries.sum(0.to_d) { |entry| entry.account_delta_for(financial_account.id) }
      [ financial_account.name, delta.to_s("F") ]
    end
  end

  def serialize_entry(entry)
    {
      id: entry.id,
      date: entry.entry_date,
      type: entry.entry_type,
      amount: entry.amount.to_d.to_s("F"),
      description: entry.description,
      category: entry.category&.name,
      financial_account: entry.financial_account&.name,
      counterparty_account: entry.counterparty_financial_account&.name,
      liability: entry.financial_liability&.name,
      planned_expense_id: entry.planned_expense_id,
      income_event_id: entry.income_event_id,
      notes: entry.notes
    }
  end
end
