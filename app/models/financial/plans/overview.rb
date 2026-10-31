class Financial::Plans::Overview
  PlanMetrics = Data.define(:expected_funding, :planned_consumption, :planned_balance, :global_balance)

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

  def plan_metrics
    @plan_metrics ||= begin
      plan_rows = plans.to_a
      plan_ids = plan_rows.map(&:id)
      funding_by_plan = Financial::FundingSource.where(financial_plan_id: plan_ids).group(:financial_plan_id).sum(:expected_amount)
      consumption_by_plan = Financial::PlannedTransaction.balance_reducing.where(income_event_id: plan_ids).group(:income_event_id).sum(:amount)
      global_balance = 0.to_d

      plan_rows.sort_by { |plan| [ plan.planned_for, plan.id ] }.each_with_object({}) do |plan, metrics|
        funding = funding_by_plan.fetch(plan.id, 0).to_d
        consumption = consumption_by_plan.fetch(plan.id, 0).to_d
        balance = funding - consumption
        global_balance += balance
        metrics[plan.id] = PlanMetrics.new(funding, consumption, balance, global_balance)
      end
    end
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
