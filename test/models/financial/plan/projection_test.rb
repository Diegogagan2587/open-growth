require "test_helper"

class Financial::Plan::ProjectionTest < ActiveSupport::TestCase
  setup do
    @account = Account.create!(name: "Projection household")
    Current.account = @account
    @category = Category.create!(account: @account, name: "Projection expense")
    @checking = Financial::Asset.create!(account: @account, name: "Checking", account_type: "checking", status: "active", opening_balance: 1_000)
    @savings = Financial::Asset.create!(account: @account, name: "Savings", account_type: "savings", status: "active", opening_balance: 250)
    @plan = Financial::Plan.create!(account: @account, name: "Flexible plan", planned_for: Date.new(2026, 9, 16), expected_amount: 1)
  end

  teardown do
    Current.account = nil
  end

  test "sums each funding source amount without using account balances" do
    @checking.update!(opening_balance: -10_000)
    add_funding("Salary", @checking, 5_000)
    add_funding("Refund", @checking, 5_000)
    add_funding("Savings", @savings, 250)

    projection = Financial::Plan::Projection.for(@plan)

    assert_equal 10_250.to_d, projection.expected_funding
  end

  test "planned funding keeps the expected amount after receipt" do
    source = add_funding("Salary", @checking, 5_000)
    Financial::Entry.create!(account: @account, funding_source: source, financial_account: @checking, entry_type: "inflow", entry_date: Date.current, amount: 4_500, description: "Salary")

    assert_equal 5_000.to_d, Financial::Plan::Projection.for(@plan).expected_funding
  end

  test "subtracts applied and pending cash requirements from plan funding" do
    add_funding("Salary", @checking, 1_000)
    paid = add_outflow("Paid", 100, Date.new(2026, 9, 15))
    assert Financial::PlannedTransactions::ApplyService.call(planned_transaction: paid).success?
    pending = add_outflow("Pending", 300, Date.new(2026, 9, 17))
    transfer = Financial::PlannedTransaction.create!(
      account: @account,
      plan: @plan,
      description: "Move money",
      amount: 200,
      due_date: Date.new(2026, 9, 18),
      status: "pending_to_pay",
      financial_account: @checking,
      counterparty_financial_account: @savings
    )

    projection = Financial::Plan::Projection.for(@plan)

    assert_equal 1_000.to_d, projection.expected_funding
    assert_equal 400.to_d, projection.planned_consumption
    assert_equal 600.to_d, projection.ending_balance
    assert_equal [ [ paid.id, 900.to_d ], [ pending.id, 600.to_d ], [ transfer.id, 600.to_d ] ], projection.rows.map { |row| [ row.transaction.id, row.balance ] }
  end

  test "reserved neutral movements reduce planned balance once whether pending or applied" do
    add_funding("Salary", @checking, 1_000)
    transfer = Financial::PlannedTransaction.create!(
      account: @account,
      plan: @plan,
      description: "Set savings aside",
      amount: 200,
      status: "pending_to_pay",
      financial_account: @checking,
      counterparty_financial_account: @savings,
      commits_plan_funds: true
    )
    Financial::PlannedTransactions::ApplyService.call(planned_transaction: transfer)

    projection = Financial::Plan::Projection.for(@plan)

    assert_equal 200.to_d, projection.planned_consumption
    assert_equal 800.to_d, projection.ending_balance
    assert_equal 800.to_d, projection.rows.first.balance
    assert_equal 0.to_d, Financial::Plan::Actuals.for(@plan).actual_consumption
  end

  test "shows the exact shortfall" do
    add_funding("Salary", @checking, 1_000)
    add_outflow("Large payment", 1_300, Date.new(2026, 9, 17))

    projection = Financial::Plan::Projection.for(@plan)

    assert_equal(-300.to_d, projection.ending_balance)
  end

  test "includes movements regardless of the plan reference date" do
    add_funding("Salary", @checking)
    before = add_outflow("Before", 100, Date.new(2026, 1, 1))
    after = add_outflow("After", 200, Date.new(2027, 1, 1))

    projection = Financial::Plan::Projection.for(@plan)

    assert_equal [ before, after ], projection.transactions
    assert_equal 300.to_d, projection.planned_consumption
  end

  test "reports missing selected funding accounts without hiding payments" do
    payment = add_outflow("Visible payment", 100, nil)

    projection = Financial::Plan::Projection.for(@plan)

    assert_equal 0.to_d, projection.expected_funding
    assert_equal 100.to_d, projection.planned_consumption
    assert_not projection.complete?
    assert_includes projection.incomplete_reasons, :funding_sources
    assert_equal [ payment ], projection.transactions
  end

  test "switches between stable due-date and saved custom order" do
    first = add_outflow("First custom", 100, Date.new(2026, 9, 20))
    second = add_outflow("Second custom", 100, Date.new(2026, 9, 18))
    unscheduled = add_outflow("Unscheduled", 100, nil)

    assert_equal [ second, first, unscheduled ], Financial::Plan::Projection.for(@plan, order: :due_date).transactions
    assert_equal [ first, second, unscheduled ], Financial::Plan::Projection.for(@plan, order: :custom).transactions
  end

  private

  def add_funding(description, asset, amount = 1)
    @plan.funding_sources.create!(
      account: @account,
      description: description,
      expected_amount: amount,
      expected_date: @plan.planned_for,
      expected_destination_asset: asset
    )
  end

  def add_outflow(description, amount, due_date)
    Financial::PlannedTransaction.create!(
      account: @account,
      plan: @plan,
      category: @category,
      description: description,
      amount: amount,
      due_date: due_date,
      status: "pending_to_pay",
      financial_account: @checking
    )
  end
end
