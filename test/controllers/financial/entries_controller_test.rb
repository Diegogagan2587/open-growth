require "test_helper"

  class Financial::EntriesControllerTest < ActionDispatch::IntegrationTest
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
        category: Category.first
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
        category: Category.first
      )

      get finance_entries_path, params: { account_ref: "asset:#{@asset_a.id}" }

      assert_response :success
      assert_select "select[name='account_ref'] option[value='asset:#{@asset_a.id}'][selected]"
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
        category: Category.first
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
        category: Category.first
      )

      get finance_entries_path, params: { account_ref: "liability:#{@liability_a.id}" }

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
        category: Category.first
      )
      second = Financial::Entry.create!(
        account: @account,
        entry_type: "outflow",
        financial_account: @asset_b,
        entry_date: Date.current,
        amount: 10,
        description: "second visible entry",
        category: Category.first
      )

      get finance_entries_path, params: { account_ref: "bad-value" }

      assert_response :success
      assert_includes response.body, first.description
      assert_includes response.body, second.description
    end
  end
