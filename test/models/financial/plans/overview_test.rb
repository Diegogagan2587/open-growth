require "test_helper"

class Financial::Plans::OverviewTest < ActiveSupport::TestCase
  setup do
    @account = Account.create!(name: "Overview household")
    Current.account = @account
    @category = Category.create!(account: @account, name: "Overview bills")
    @asset = Financial::Asset.create!(account: @account, name: "Overview checking", account_type: "checking", status: "active", opening_balance: 0)
  end

  teardown do
    Current.account = nil
  end

  test "summarizes only the supplied plans relation" do
    active = create_plan("Active", 500, "active")
    create_payment(active, 300)
    closed = create_plan("Closed", 900, "active")
    create_payment(closed, 100)
    closed.update!(lifecycle_status: "closed")

    overview = Financial::Plans::Overview.for(Financial::Plan.for_account(@account).where(lifecycle_status: "active"))

    assert_equal 1, overview.plan_count
    assert_equal 500.to_d, overview.expected_funding
    assert_equal 300.to_d, overview.planned_consumption
    assert_equal 200.to_d, overview.planned_balance
  end

  test "uses the plan balance predicate for reserved neutral movements" do
    plan = create_plan("Reserved", 500, "active")
    destination = Financial::Asset.create!(account: @account, name: "Overview savings", account_type: "savings", status: "active", opening_balance: 0)
    Financial::PlannedTransaction.create!(account: @account, plan:, financial_account: @asset, counterparty_financial_account: destination, description: "Unreserved transfer", amount: 100, status: "pending_to_pay")
    Financial::PlannedTransaction.create!(account: @account, plan:, financial_account: @asset, counterparty_financial_account: destination, description: "Reserved transfer", amount: 150, status: "pending_to_pay", commits_plan_funds: true)

    overview = Financial::Plans::Overview.for(Financial::Plan.where(id: plan.id))

    assert_equal 150.to_d, overview.planned_consumption
    assert_equal 350.to_d, overview.planned_balance
  end

  private

  def create_plan(name, expected_funding, status)
    plan = Financial::Plan.create!(account: @account, name:, planned_for: Date.current, expected_amount: 1, lifecycle_status: "active")
    plan.funding_sources.create!(account: @account, description: "#{name} funding", expected_amount: expected_funding, expected_date: Date.current, expected_destination_asset: @asset)
    plan.update!(lifecycle_status: status) unless status == "active"
    plan
  end

  def create_payment(plan, amount)
    Financial::PlannedTransaction.create!(account: @account, plan:, category: @category, financial_account: @asset, description: "#{plan.name} payment", amount:, status: "pending_to_pay")
  end
end
