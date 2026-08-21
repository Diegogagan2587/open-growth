require "test_helper"

class Financial::BudgetAllocationsControllerTest < ActionDispatch::IntegrationTest
  setup do
    @user = users(:one)
    @account = accounts(:one)
    @period = BudgetPeriod.create!(
      account: @account,
      name: "August",
      start_date: Date.new(2026, 8, 1),
      end_date: Date.new(2026, 8, 31),
      total_amount: 0
    )
    sign_in_as(@user, @account)
  end

  teardown { Current.reset }

  test "renders and creates a category allocation" do
    get budget_period_path(@period)
    assert_response :success
    assert_select "h2", text: "Budget allocations"

    assert_difference "Financial::BudgetAllocation.count", 1 do
      post finance_budget_period_budget_allocations_path(@period), params: {
        financial_budget_allocation: {
          category_id: categories(:one).id,
          planned_amount: 250
        }
      }
    end

    assert_redirected_to budget_period_path(@period)
    allocation = Financial::BudgetAllocation.order(:id).last
    assert_equal @account, allocation.account
    assert_equal 250.to_d, allocation.planned_amount
  end

  test "does not expose another household budget period" do
    hidden_period = BudgetPeriod.create!(
      account: accounts(:two),
      name: "Hidden",
      start_date: Date.new(2026, 8, 1),
      end_date: Date.new(2026, 8, 31),
      total_amount: 0
    )

    post finance_budget_period_budget_allocations_path(hidden_period), params: {
      financial_budget_allocation: {
        category_id: categories(:one).id,
        planned_amount: 100
      }
    }

    assert_response :not_found
  end
end
