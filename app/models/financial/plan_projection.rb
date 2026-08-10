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
    plan.planned_expenses.committed_to_plan.sum(:amount)
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
    plan.planned_expenses.includes(:financial_account, :counterparty_financial_account, :financial_liability).by_position.map do |transaction|
      balance -= transaction.amount.to_d if transaction.reduces_plan_balance?
      Row.new(transaction:, balance:)
    end
  end

  def first_deficit_transaction
    rows.find { |row| row.balance.negative? }&.transaction
  end

  private

  attr_reader :plan

  def preceding_plans
    plan.account.income_events
      .where("expected_date < :date OR (expected_date = :date AND id < :id)", date: plan.expected_date, id: plan.id)
      .order(:expected_date, :id)
  end


  def projected_funding_for(candidate)
    sources = Financial::FundingSource.where(financial_plan_id: candidate.id)
    return sources.sum(:expected_amount).to_d if sources.exists?

    candidate.expected_amount.to_d
  end
end
