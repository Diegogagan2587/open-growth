class Financial::Plans::Overview
  def self.for(plans)
    new(plans)
  end

  def initialize(plans)
    @plans = plans
  end

  def plan_count
    plans.count
  end

  def expected_funding
    funding_sources.sum(0.to_d) { |source| source.expected_amount.to_d }
  end

  def planned_consumption
    planned_transactions.balance_reducing.sum(:amount)
  end

  def planned_balance
    expected_funding - planned_consumption
  end

  private

  attr_reader :plans

  def funding_sources
    @funding_sources ||= Financial::FundingSource.where(financial_plan_id: plans.select(:id))
  end

  def planned_transactions
    @planned_transactions ||= Financial::PlannedTransaction.where(income_event_id: plans.select(:id))
  end
end
