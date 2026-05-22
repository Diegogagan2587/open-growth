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
    @asset_a = Financial::Asset.create!(
      account: @account,
      name: "Cash",
      account_type: "checking",
      status: "active",
      opening_balance: 100
    )
    @asset_b = Financial::Asset.create!(
      account: @account,
      name: "Savings",
      account_type: "savings",
      status: "active",
      opening_balance: 20
    )
    @liability = Financial::Liability.create!(
      account: @account,
      name: "Credit Card",
      liability_type: "credit_card",
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

  test "quick add income to asset creates inflow entry and increases balance" do
    assert_difference -> { Financial::Entry.count }, 1 do
      post quick_add_create_income_path, params: {
        income: {
          description: "Salary",
          expected_amount: 50,
          expected_date: Date.new(2026, 5, 7),
          destination: "asset_#{@asset_a.id}"
        }
      }
    end

    assert_response :created
    assert_equal 150.to_d, @asset_a.reload.current_balance
  end

  test "quick add expense from asset creates outflow entry and decreases balance" do
    assert_difference -> { Financial::Entry.count }, 1 do
      post quick_add_create_expense_path, params: {
        expense: {
          description: "Groceries",
          amount: 30.45,
          category_id: @category.id,
          date: Date.new(2026, 5, 7),
          origin: "asset_#{@asset_a.id}"
        }
      }
    end

    assert_response :created
    assert_equal 69.55.to_d, @asset_a.reload.current_balance
  end

  test "quick add transfer asset to asset updates both balances" do
    assert_difference -> { Financial::Entry.count }, 1 do
      post quick_add_create_transfer_path, params: {
        transfer: {
          amount: 25,
          from_type: "asset_#{@asset_a.id}",
          to_type: "asset_#{@asset_b.id}"
        }
      }
    end

    assert_response :created
    assert_equal 75.to_d, @asset_a.reload.current_balance
    assert_equal 45.to_d, @asset_b.reload.current_balance
  end

  test "quick add transfer asset to liability reduces liability and asset" do
    assert_difference -> { Financial::Entry.count }, 1 do
      post quick_add_create_transfer_path, params: {
        transfer: {
          amount: 40,
          from_type: "asset_#{@asset_a.id}",
          to_type: "liability_#{@liability.id}"
        }
      }
    end

    assert_response :created
    assert_equal 60.to_d, @asset_a.reload.current_balance
    assert_equal 160.to_d, @liability.reload.current_balance
  end

  test "quick add transfer allows same numeric id when account types differ (asset to liability)" do
    asset_max_id = Financial::Asset.for_account(@account).maximum(:id).to_i
    liability_max_id = Financial::Liability.for_account(@account).maximum(:id).to_i

    if asset_max_id > liability_max_id
      (asset_max_id - liability_max_id).times do |i|
        Financial::Liability.create!(
          account: @account,
          name: "Liability align #{i}",
          liability_type: "credit_card",
          status: "active",
          opening_balance: 100
        )
      end
    elsif liability_max_id > asset_max_id
      (liability_max_id - asset_max_id).times do |i|
        Financial::Asset.create!(
          account: @account,
          name: "Asset align #{i}",
          account_type: "checking",
          status: "active",
          opening_balance: 100
        )
      end
    end

    overlap_asset = Financial::Asset.create!(
      account: @account,
      name: "Asset overlap deterministic",
      account_type: "checking",
      status: "active",
      opening_balance: 100
    )
    overlap_liability = Financial::Liability.create!(
      account: @account,
      name: "Liability overlap deterministic",
      liability_type: "credit_card",
      status: "active",
      opening_balance: 100
    )

    assert_equal overlap_asset.id, overlap_liability.id, "Expected asset/liability id overlap for deterministic edge-case coverage"

    assert_difference -> { Financial::Entry.count }, 1 do
      post quick_add_create_transfer_path, params: {
        transfer: {
          amount: 25,
          from_type: "asset_#{overlap_asset.id}",
          to_type: "liability_#{overlap_liability.id}"
        }
      }
    end

    assert_response :created
    assert_equal 75.to_d, overlap_asset.reload.current_balance
    assert_equal 75.to_d, overlap_liability.reload.current_balance
  end

  test "quick add income to liability reduces liability balance" do
    assert_difference -> { Financial::Entry.count }, 1 do
      post quick_add_create_income_path, params: {
        income: {
          description: "Bonus to debt",
          expected_amount: 35,
          expected_date: Date.new(2026, 5, 7),
          destination: "liability_#{@liability.id}"
        }
      }
    end

    assert_response :created
    assert_equal 165.to_d, @liability.reload.current_balance
  end
end
