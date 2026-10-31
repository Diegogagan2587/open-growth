require "test_helper"

class Financial::Plans::PlannedTransactionOrdersControllerTest < ActionDispatch::IntegrationTest
  setup do
    @user = users(:one)
    @account = accounts(:one)
    sign_in_as(@user, @account)
    @category = categories(:one)
    @asset = Financial::Asset.create!(account: @account, name: "Order checking", account_type: "checking", status: "active", opening_balance: 500)
    @plan = Financial::Plan.create!(account: @account, name: "Order plan", planned_for: Date.current, expected_amount: 1)
    @first = create_transaction("First")
    @second = create_transaction("Second")
  end

  teardown do
    Current.account = nil
    Current.session = nil
  end

  test "replaces the complete custom order" do
    patch finance_plan_planned_transaction_order_path(@plan), params: {
      planned_transaction_order: { ordered_ids: [ @second.id, @first.id ] }
    }

    assert_redirected_to finance_plan_path(@plan, order: "custom")
    assert_equal [ @second.id, @first.id ], @plan.planned_transactions.by_position.ids
  end

  test "rejects an incomplete order without changing positions" do
    patch finance_plan_planned_transaction_order_path(@plan), params: {
      planned_transaction_order: { ordered_ids: [ @second.id ] }
    }

    assert_redirected_to finance_plan_path(@plan)
    assert_equal [ @first.id, @second.id ], @plan.planned_transactions.by_position.ids
    assert flash[:alert].present?
  end

  private

  def create_transaction(description)
    Financial::PlannedTransaction.create!(account: @account, plan: @plan, category: @category, financial_account: @asset, description:, amount: 25, status: "pending_to_pay")
  end
end
