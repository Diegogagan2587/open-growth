class Financial::PlanActuals
  FUNDING_TRANSACTION_TYPES = %w[income loan_disbursement refund].freeze

  def self.for(plan)
    new(plan)
  end

  def initialize(plan)
    @plan = plan.is_a?(Financial::Plan) ? plan : Financial::Plan.find(plan.id)
  end

  def actual_funding
    transactions.funding.sum(:amount)
  end

  def actual_consumption
    transactions.expenses.sum(:amount)
  end

  def opening_balance
    preceding_plans.reduce(0.to_d) do |balance, preceding_plan|
      if preceding_plan.lifecycle_status == "closed" && preceding_plan.actual_ending_balance_at_close.present?
        next preceding_plan.actual_ending_balance_at_close.to_d
      end

      preceding_transactions = preceding_plan.transactions
      balance + preceding_transactions.funding.sum(:amount).to_d -
        preceding_transactions.expenses.sum(:amount).to_d
    end
  end

  def ending_balance
    opening_balance + actual_funding - actual_consumption
  end

  private

  attr_reader :plan

  def transactions
    plan.transactions
  end

  def preceding_plans
    plan.account.financial_plans
      .where("planned_for < :date OR (planned_for = :date AND id < :id)", date: plan.planned_for, id: plan.id)
      .order(:planned_for, :id)
  end
end
