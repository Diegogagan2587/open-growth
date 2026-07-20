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
end
