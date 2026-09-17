class Financial::Plan::Actuals
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
end
