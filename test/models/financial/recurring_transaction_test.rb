require "test_helper"

class Financial::RecurringTransactionTest < ActiveSupport::TestCase
  setup do
    @account = Account.create!(name: "Recurring household")
    @category = Category.create!(account: @account, name: "Savings")
    @checking = Financial::Account.create!(account: @account, name: "Checking", account_group: "asset", account_type: "checking", status: "active", opening_balance: 0)
    @savings = Financial::Account.create!(account: @account, name: "Savings", account_group: "asset", account_type: "savings", status: "active", opening_balance: 0)
    @plan = Financial::Plan.create!(account: @account, name: "August", planned_for: Date.new(2026, 8, 15))
    Current.account = @account
  end

  teardown { Current.reset }

  test "builds an independent planned occurrence from recurring defaults" do
    recurring = Financial::RecurringTransaction.create!(
      account: @account,
      category: @category,
      source_account: @checking,
      destination_account: @savings,
      name: "Emergency contribution",
      description: "Move money to savings",
      amount: 500,
      frequency: "quincenal",
      transaction_kind: "transfer",
      budget_consuming: true,
      importance: "essential",
      status: "active"
    )

    occurrence = recurring.build_occurrence(plan: @plan)
    occurrence.save!
    recurring.update!(amount: 650, description: "Updated default")

    assert_equal recurring, occurrence.recurring_transaction
    assert_equal 500.to_d, occurrence.planned_amount
    assert_equal "Move money to savings", occurrence.description
    assert_equal "transfer", occurrence.kind
    assert occurrence.budget_consuming?
    assert_equal @plan.planned_for, occurrence.planned_execution_date
  end

  test "explicit budget policy controls projection independently of transaction kind" do
    @plan.funding_sources.create!(account: @account, description: "Salary", expected_amount: 1_000, expected_date: @plan.planned_for, expected_destination_account: @checking)
    recurring = Financial::RecurringTransaction.create!(account: @account, category: @category, source_account: @checking, destination_account: @savings, name: "Savings", amount: 300, frequency: "monthly", transaction_kind: "transfer", budget_consuming: true, importance: "normal", status: "active")
    recurring.build_occurrence(plan: @plan).save!

    assert_equal 300.to_d, Financial::PlanProjection.for(@plan).planned_consumption
    assert_equal 700.to_d, Financial::PlanProjection.for(@plan).ending_balance
  end

  test "infers transaction kind from its account route" do
    recurring = Financial::RecurringTransaction.create!(
      account: @account,
      category: @category,
      source_account: @checking,
      destination_account: @savings,
      name: "Automatic transfer",
      amount: 300,
      frequency: "monthly",
      budget_consuming: false,
      importance: "normal",
      status: "active"
    )

    assert_equal "transfer", recurring.transaction_kind
  end
  test "allows an incomplete account route while planning" do
    recurring = Financial::RecurringTransaction.new(
      account: @account,
      destination_account: @savings,
      name: "Choose source later",
      amount: 300,
      frequency: "monthly",
      budget_consuming: false,
      importance: "normal",
      status: "active"
    )

    assert recurring.valid?
    assert_equal "transfer", recurring.transaction_kind
  end
end
