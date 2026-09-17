require "test_helper"

class Financial::PlanTest < ActiveSupport::TestCase
  test "uses planning language over the compatible income event row" do
    account = Account.create!(name: "Plan Tenant")
    plan = Financial::Plan.create!(
      account: account,
      name: "July plan",
      planned_for: Date.new(2026, 7, 1),
      expected_amount: 1,
      lifecycle_status: "draft"
    )

    assert_equal "July plan", plan.description
    assert_equal Date.new(2026, 7, 1), plan.expected_date
    assert_equal "draft", plan.lifecycle_status
    assert_instance_of Financial::Plan, Financial::Plan.find(plan.id)
  end

  test "reorders every planned movement atomically without changing actual entries" do
    account = Account.create!(name: "Ordered Plan Tenant")
    category = Category.create!(account:, name: "Bills")
    asset = Financial::Asset.create!(account:, name: "Checking", account_type: "checking", status: "active", opening_balance: 500)
    plan = Financial::Plan.create!(account:, name: "Ordered plan", planned_for: Date.current, expected_amount: 1)
    first = create_transaction(account:, plan:, category:, asset:, description: "First")
    second = create_transaction(account:, plan:, category:, asset:, description: "Second")
    applied = create_transaction(account:, plan:, category:, asset:, description: "Applied")
    result = Financial::PlannedTransactions::ApplyService.call(planned_transaction: applied)
    entry_attributes = result.entry.attributes.slice("id", "entry_date", "amount", "financial_account_id")

    plan.reorder_planned_transactions!([ applied.id, first.id, second.id ])

    assert plan.reload.custom_ordered?
    assert_equal [ [ applied.id, 1 ], [ first.id, 2 ], [ second.id, 3 ] ], plan.planned_transactions.by_position.pluck(:id, :position)
    assert_equal entry_attributes, result.entry.reload.attributes.slice(*entry_attributes.keys)
  ensure
    Current.account = nil
  end

  test "rejects incomplete or duplicate orders without partial writes" do
    account = Account.create!(name: "Invalid Order Tenant")
    category = Category.create!(account:, name: "Bills")
    asset = Financial::Asset.create!(account:, name: "Checking", account_type: "checking", status: "active", opening_balance: 500)
    plan = Financial::Plan.create!(account:, name: "Invalid order", planned_for: Date.current, expected_amount: 1)
    first = create_transaction(account:, plan:, category:, asset:, description: "First")
    second = create_transaction(account:, plan:, category:, asset:, description: "Second")

    assert_raises(ActiveRecord::RecordInvalid) { plan.reorder_planned_transactions!([ first.id, first.id ]) }
    assert_equal [ [ first.id, 1 ], [ second.id, 2 ] ], plan.planned_transactions.by_position.pluck(:id, :position)
    assert_not plan.reload.custom_ordered?
  ensure
    Current.account = nil
  end

  test "appends a new movement after an established custom order" do
    account = Account.create!(name: "Append Order Tenant")
    category = Category.create!(account:, name: "Bills")
    asset = Financial::Asset.create!(account:, name: "Checking", account_type: "checking", status: "active", opening_balance: 500)
    plan = Financial::Plan.create!(account:, name: "Append order", planned_for: Date.current, expected_amount: 1)
    first = create_transaction(account:, plan:, category:, asset:, description: "First")
    second = create_transaction(account:, plan:, category:, asset:, description: "Second")
    plan.reorder_planned_transactions!([ second.id, first.id ])

    appended = create_transaction(account:, plan:, category:, asset:, description: "Appended")

    assert_equal 3, appended.position
    assert_equal [ second.id, first.id, appended.id ], plan.planned_transactions.by_position.ids
  ensure
    Current.account = nil
  end

  private

  def create_transaction(account:, plan:, category:, asset:, description:)
    Current.account = account
    Financial::PlannedTransaction.create!(
      account:,
      plan:,
      category:,
      financial_account: asset,
      description:,
      amount: 25,
      due_date: Date.current,
      status: "pending_to_pay"
    )
  end
end
