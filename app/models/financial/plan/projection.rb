class Financial::Plan::Projection
  AccountBalance = Data.define(:account, :amount)
  Row = Data.define(:transaction, :balance)

  def self.for(plan, order: nil)
    new(plan, order:)
  end

  def initialize(plan, order: nil)
    @plan = plan
    @order = order
  end

  def expected_funding
    funding_sources.sum(0.to_d) { |source| source.expected_amount.to_d }
  end

  def account_balances
    @account_balances ||= selected_accounts.map do |account|
      AccountBalance.new(account:, amount: account.current_balance.to_d)
    end
  end

  def planned_consumption
    plan_transactions.select(&:reduces_plan_balance?).sum(0.to_d) { |transaction| transaction.amount.to_d }
  end

  def opening_balance
    expected_funding
  end

  def ending_balance
    expected_funding - planned_consumption
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

  def selected_accounts
    @selected_accounts ||= Financial::FundingSource
      .where(financial_plan_id: plan.id)
      .where.not(expected_destination_asset_id: nil)
      .includes(:expected_destination_asset)
      .map(&:expected_destination_asset)
      .uniq(&:id)
      .sort_by(&:id)
  end

  def funding_sources
    @funding_sources ||= plan.funding_sources.includes(:receipt_entry, :expected_destination_asset).to_a
  end
end
