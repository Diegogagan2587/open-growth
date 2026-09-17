class Financial::Plan::Actuals
  FUNDING_ENTRY_TYPES = %w[inflow loan_disbursement].freeze

  def self.for(plan)
    new(plan)
  end

  def initialize(plan)
    @plan = plan
  end

  def actual_funding
    Financial::Entry.where(funding_source_id: plan.funding_sources.select(:id)).sum(:amount)
  end

  def actual_consumption
    entries.where(entry_type: Financial::Entry::EXPENSE_ENTRY_TYPES).sum(:amount)
  end

  def opening_balance
    0.to_d
  end

  def ending_balance
    opening_balance + actual_funding - actual_consumption
  end

  private

  attr_reader :plan

  def entries
    plan.financial_entries
  end

  def preceding_plans
    plan.account.income_events
      .where("expected_date < :date OR (expected_date = :date AND id < :id)", date: plan.expected_date, id: plan.id)
      .order(:expected_date, :id)
  end
end
