require "test_helper"

class QuickAddControllerTest < ActionDispatch::IntegrationTest
  setup do
    @user = users(:one)
    @account = @user.accounts.first
    sign_in_as(@user, @account)
    @category = categories(:one)
    @budget_period = @account.budget_periods.create!(
      name: "May 2026",
      start_date: Date.new(2026, 5, 1),
      end_date: Date.new(2026, 5, 31)
    )
    @asset_a = Financial::Account.create!(
      account: @account,
      name: "Cash",
      account_group: "asset",
      account_type: "checking",
      status: "active",
      opening_balance: 100
    )
    @asset_b = Financial::Account.create!(
      account: @account,
      name: "Savings",
      account_group: "asset",
      account_type: "savings",
      status: "active",
      opening_balance: 20
    )
    @liability = Financial::Account.create!(
      account: @account,
      name: "Credit Card",
      account_group: "liability",
      account_type: "credit_card",
      status: "active",
      opening_balance: 200
    )
  end

  test "quick add controller actions are defined" do
    assert_respond_to QuickAddController.new, :financial
    assert_respond_to QuickAddController.new, :create_income
    assert_respond_to QuickAddController.new, :create_expense
    assert_respond_to QuickAddController.new, :create_transfer
  end

  test "quick add income creates an unreconciled transaction and increases the asset balance" do
    assert_difference -> { Financial::Transaction.count }, 1 do
      post quick_add_create_income_path, params: {
        income: {
          description: "Salary",
          expected_amount: 50,
          expected_date: Date.new(2026, 5, 7),
          destination: @asset_a.id
        }
      }
    end

    assert_response :created
    assert_equal 150.to_d, @asset_a.reload.current_balance
    assert_nil Financial::Transaction.order(:created_at).last.reconciled_at
  end

  test "quick add expense from asset creates outflow entry and decreases balance" do
    assert_difference -> { Financial::Transaction.count }, 1 do
      post quick_add_create_expense_path, params: {
        expense: {
          description: "Groceries",
          amount: 30.45,
          category_id: @category.id,
          date: Date.new(2026, 5, 7),
          time: "14:35",
          origin: "asset_#{@asset_a.id}"
        }
      }
    end

    assert_response :created
    assert_equal 69.55.to_d, @asset_a.reload.current_balance
    assert_equal "14:35", Financial::Entry.order(:created_at).last.entry_time.strftime("%H:%M")
  end

  test "quick add expense assigns the selected plan" do
    plan = Financial::Plan.create!(
      account: @account,
      budget_period: @budget_period,
      name: "May salary",
      planned_for: Date.new(2026, 5, 1),
      lifecycle_status: "active"
    )

    post quick_add_create_expense_path, params: {
      expense: {
        description: "Groceries",
        amount: 30.45,
        category_id: @category.id,
        date: Date.new(2026, 5, 7),
        origin: @asset_a.id,
        income_event_id: plan.id
      }
    }

    assert_response :created
    assert_equal plan, Financial::Transaction.order(:created_at).last.plan
  end

  test "quick add transfer asset to asset updates both balances" do
    assert_difference -> { Financial::Transaction.count }, 1 do
      post quick_add_create_transfer_path, params: {
        transfer: {
          amount: 25,
          date: Date.new(2026, 5, 9),
          time: "08:10",
          from_type: "asset_#{@asset_a.id}",
          to_type: "asset_#{@asset_b.id}"
        }
      }
    end

    assert_response :created
    assert_equal 75.to_d, @asset_a.reload.current_balance
    assert_equal 45.to_d, @asset_b.reload.current_balance
    entry = Financial::Entry.order(:created_at).last
    assert_equal Date.new(2026, 5, 9), entry.entry_date
    assert_equal "08:10", entry.entry_time.strftime("%H:%M")
  end

  test "quick add transfer asset to liability reduces liability and asset" do
    assert_difference -> { Financial::Transaction.count }, 1 do
      post quick_add_create_transfer_path, params: {
        transfer: {
          amount: 40,
          from_type: @asset_a.id,
          to_type: @liability.id
        }
      }
    end

    assert_response :created
    assert_equal 60.to_d, @asset_a.reload.current_balance
    assert_equal 160.to_d, @liability.reload.current_balance
  end

  test "quick add income to liability reduces liability balance" do
    assert_difference -> { Financial::Transaction.count }, 1 do
      post quick_add_create_income_path, params: {
        income: {
          description: "Bonus to debt",
          expected_amount: 35,
          expected_date: Date.new(2026, 5, 7),
          time: "09:45",
          destination: "liability_#{@liability.id}"
        }
      }
    end

    assert_response :created
    assert_equal 165.to_d, @liability.reload.current_balance
    assert_equal "09:45", Financial::Entry.order(:created_at).last.entry_time.strftime("%H:%M")
  end

  test "quick add entries allow a blank time" do
    post quick_add_create_expense_path, params: {
      expense: {
        description: "Untimed expense",
        amount: 10,
        category_id: @category.id,
        date: Date.new(2026, 5, 7),
        origin: "asset_#{@asset_a.id}"
      }
    }

    assert_response :created
    assert_nil Financial::Entry.order(:created_at).last.entry_time
  end
end
