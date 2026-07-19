class Financial::PlanActuals
  FUNDING_ENTRY_TYPES = %w[inflow loan_disbursement].freeze

  def self.for(plan)
    new(plan)
  end

  def initialize(plan)
    @plan = plan
  end

  def actual_funding
    entries.where(entry_type: FUNDING_ENTRY_TYPES).sum(:amount)
  end

  def actual_consumption
    entries.where(entry_type: Financial::Entry::EXPENSE_ENTRY_TYPES).sum(:amount)
  end

  def opening_balance
    preceding_plans.reduce(0.to_d) do |balance, preceding_plan|
      if preceding_plan.lifecycle_status == "closed" && preceding_plan.actual_ending_balance_at_close.present?
        next preceding_plan.actual_ending_balance_at_close.to_d
      end

      preceding_entries = preceding_plan.financial_entries
      balance + preceding_entries.where(entry_type: FUNDING_ENTRY_TYPES).sum(:amount).to_d -
        preceding_entries.where(entry_type: Financial::Entry::EXPENSE_ENTRY_TYPES).sum(:amount).to_d
    end
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
