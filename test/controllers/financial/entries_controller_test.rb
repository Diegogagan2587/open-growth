require "test_helper"

module Financial
  class EntriesControllerTest < ActionDispatch::IntegrationTest
    def setup
      @user = users(:one)
      @account = accounts(:one)
      @category = categories(:one)
      @income_event = income_events(:one)

      @asset_a = Financial::Asset.create!(
        account: @account,
        name: "Wallet A",
        account_type: "checking",
        status: "active",
        opening_balance: 0
      )
      @asset_b = Financial::Asset.create!(
        account: @account,
        name: "Wallet B",
        account_type: "savings",
        status: "active",
        opening_balance: 0
      )
      @liability_a = Financial::Liability.create!(
        account: @account,
        name: "Mastercard",
        liability_type: "credit_card",
        status: "active",
        opening_balance: 0
      )
    end

    def sign_in
      post session_path, params: {
        email_address: @user.email_address,
        password: "password"
      }
      Current.account = @account
    end

    def teardown
      Current.account = nil
      Current.session = nil
    end

    test "index filters entries by asset account on source or counterparty side" do
      sign_in

      source_match = Financial::Entry.create!(
        account: @account,
        entry_type: "outflow",
        financial_account: @asset_a,
        entry_date: Date.current,
        amount: 10,
        description: "entry source match",
        category: @category
      )
      counterparty_match = Financial::Entry.create!(
        account: @account,
        entry_type: "transfer",
        financial_account: @asset_b,
        counterparty_financial_account: @asset_a,
        entry_date: Date.current,
        amount: 20,
        description: "entry counterparty match"
      )
      non_match = Financial::Entry.create!(
        account: @account,
        entry_type: "outflow",
        financial_account: @asset_b,
        entry_date: Date.current,
        amount: 30,
        description: "entry non match",
        category: @category
      )

      get finance_transactions_path, params: { account_id: @asset_a.id }

      assert_response :success
      assert_select "select[name='account_id'] option[value='#{@asset_a.id}'][selected]"
      assert_includes response.body, source_match.description
      assert_includes response.body, counterparty_match.description
      assert_not_includes response.body, non_match.description
    end

    test "index filters entries by liability account on source or counterparty side" do
      sign_in

      source_match = Financial::Entry.create!(
        account: @account,
        entry_type: "liability_charge",
        financial_liability: @liability_a,
        entry_date: Date.current,
        amount: 40,
        description: "liability source match",
        category: @category
      )
      counterparty_match = Financial::Entry.create!(
        account: @account,
        entry_type: "inflow",
        counterparty_financial_liability: @liability_a,
        entry_date: Date.current,
        amount: 50,
        description: "liability counterparty match"
      )
      non_match = Financial::Entry.create!(
        account: @account,
        entry_type: "outflow",
        financial_account: @asset_a,
        entry_date: Date.current,
        amount: 60,
        description: "liability non match",
        category: @category
      )

      get finance_transactions_path, params: { account_id: @liability_a.id }

      assert_response :success
      assert_includes response.body, source_match.description
      assert_includes response.body, counterparty_match.description
      assert_not_includes response.body, non_match.description
    end

    test "index ignores malformed account_ref" do
      sign_in

      first = Financial::Entry.create!(
        account: @account,
        entry_type: "outflow",
        financial_account: @asset_a,
        entry_date: Date.current,
        amount: 10,
        description: "first visible entry",
        category: @category
      )
      second = Financial::Entry.create!(
        account: @account,
        entry_type: "outflow",
        financial_account: @asset_b,
        entry_date: Date.current,
        amount: 10,
        description: "second visible entry",
        category: @category
      )

      get finance_transactions_path, params: { account_id: "bad-value" }

      assert_response :success
      assert_includes response.body, first.description
      assert_includes response.body, second.description
    end

    test "index renders responsive transaction records" do
      sign_in

      entry = Financial::Entry.create!(
        account: @account,
        entry_type: "outflow",
        financial_account: @asset_a,
        entry_date: Date.current,
        amount: 10,
        description: "responsive transaction",
        category: @category
      )

      get finance_transactions_path

      assert_response :success
      assert_select "article"
      assert_select "a[href='#{finance_transaction_path(entry)}']", text: entry.description
      assert_includes response.body, "responsive transaction"
    end

    test "index shows both sides of account movements" do
      sign_in
      Financial::Entry.create!(
        account: @account,
        entry_type: "transfer",
        financial_account: @asset_a,
        counterparty_financial_account: @asset_b,
        entry_date: Date.current,
        amount: 75,
        description: "Move savings"
      )
      Financial::Entry.create!(
        account: @account,
        entry_type: "outflow",
        financial_account: @asset_a,
        category: @category,
        entry_date: Date.current,
        amount: 20,
        description: "Lunch"
      )

      get finance_transactions_path

      assert_response :success
      assert_includes response.body, @asset_a.name
      assert_includes response.body, @asset_b.name
      assert_includes response.body, "Move savings"
      assert_includes response.body, "Lunch"
    end

    test "show renders routing planning notes and record metadata" do
      sign_in
      budget_period = BudgetPeriod.create!(
        account: @account,
        name: "Detailed month",
        period_type: "monthly",
        start_date: Date.current.beginning_of_month,
        end_date: Date.current.end_of_month
      )
      planned_expense = PlannedExpense.create!(
        account: @account,
        income_event: @income_event,
        category: @category,
        description: "Planned transfer",
        amount: 42,
        status: "pending_to_pay"
      )
      entry = Financial::Entry.create!(
        account: @account,
        entry_type: "transfer",
        financial_account: @asset_a,
        counterparty_financial_account: @asset_b,
        income_event: @income_event,
        planned_expense: planned_expense,
        budget_period: budget_period,
        category: @category,
        entry_date: Date.current,
        amount: 42,
        description: "Detailed transaction",
        notes: "Visible transaction notes"
      )

      get finance_transaction_path(entry)

      assert_response :success
      assert_includes response.body, "Money movement"
      assert_includes response.body, @asset_a.name
      assert_includes response.body, @asset_b.name
      assert_includes response.body, @category.name
      assert_includes response.body, budget_period.name
      assert_includes response.body, @income_event.description
      assert_includes response.body, planned_expense.description
      assert_includes response.body, "Visible transaction notes"
      assert_includes response.body, "Last updated"
    end

    test "show page renders" do
      sign_in
      entry = Financial::Entry.create!(
        account: @account,
        entry_type: "outflow",
        financial_account: @asset_a,
        category: @category,
        entry_date: Date.current,
        amount: 20,
        description: "Rendered transaction"
      )

      get finance_transaction_path(entry)

      assert_response :success
    end

    test "edit shows and updates entry time" do
      sign_in
      entry = Financial::Entry.create!(
        account: @account,
        entry_type: "outflow",
        financial_account: @asset_a,
        category: @category,
        entry_date: Date.current,
        entry_time: "08:15",
        amount: 20,
        description: "Timed transaction"
      )

      get edit_finance_transaction_path(entry)

      assert_response :success
      assert_select "input[name='financial_transaction[entry_time]'][type='time'][value='08:15']"

      patch finance_transaction_path(entry), params: { financial_transaction: {
        transaction_type: entry.transaction_type,
        transaction_date: entry.transaction_date,
        entry_time: "17:45",
        amount: entry.amount,
        description: entry.description,
        source_account_id: @asset_a.id,
        category_id: @category.id
      } }

      assert_redirected_to finance_transaction_path(entry)
      assert_equal "17:45", entry.reload.entry_time.strftime("%H:%M")
    end
  end
end
