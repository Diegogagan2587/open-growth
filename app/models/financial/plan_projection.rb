class Financial::PlanProjection
  Row = Data.define(:transaction, :balance)

  def self.for(plan)
    new(plan)
  end

  def initialize(plan)
    @plan = plan.is_a?(Financial::Plan) ? plan : Financial::Plan.find(plan.id)
  end

  def expected_funding
    projected_funding_for(plan)
  end

  def planned_consumption
    plan.planned_transactions.budget_consuming.sum(:planned_amount)
  end

  def planned_commitments
    plan.planned_transactions.committed_to_plan.sum(:planned_amount)
  end

  def opening_balance
    preceding_plans.sum(0.to_d) do |preceding_plan|
      projected_funding_for(preceding_plan) - preceding_plan.planned_transactions.budget_consuming.sum(:planned_amount).to_d
    end
  end

  def ending_balance
    opening_balance + expected_funding - planned_consumption - planned_commitments
  end

  def rows
    balance = opening_balance + expected_funding
    plan.planned_transactions.by_position.map do |transaction|
      balance -= transaction.planned_amount.to_d if transaction.budget_consuming?
      Row.new(transaction:, balance:)
    end
  end

  def first_deficit_transaction
    rows.find { |row| row.balance.negative? }&.transaction
  end

  private

  attr_reader :plan

  def preceding_plans
    plan.account.financial_plans
      .where("planned_for < :date OR (planned_for = :date AND id < :id)", date: plan.planned_for, id: plan.id)
      .order(:planned_for, :id)
  end


  def projected_funding_for(candidate)
    sources = Financial::FundingSource.where(financial_plan_id: candidate.id)
    return sources.sum(:expected_amount).to_d if sources.exists?

    0.to_d
  end
end
