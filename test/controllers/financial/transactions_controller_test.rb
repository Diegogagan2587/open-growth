require "test_helper"

class Financial::TransactionsControllerTest < ActionDispatch::IntegrationTest
  setup do
    @user = users(:one)
    @account = accounts(:one)
    @checking = Financial::Account.create!(account: @account, name: "Request checking", account_group: "asset", account_type: "checking", status: "active", opening_balance: 0)
    @transaction = Financial::Transaction.create!(account: @account, source_account: @checking, category: categories(:one), transaction_type: "expense", transaction_date: Date.current, amount: 5, description: "Snack")
    sign_in_as(@user, @account)
  end

  teardown { Current.reset }

  test "corrects and reconciles a transaction through focused resources" do
    post finance_transaction_reconciliation_path(@transaction)
    assert_redirected_to finance_transaction_path(@transaction)
    assert @transaction.reload.reconciled_at?

    patch finance_transaction_path(@transaction), params: { financial_transaction: { amount: 6, transaction_type: "expense", transaction_date: Date.current, description: "Snack", source_account_id: @checking.id, category_id: categories(:one).id } }
    assert_redirected_to finance_transaction_path(@transaction)
    assert_equal 6.to_d, @transaction.reload.amount
    assert_nil @transaction.reconciled_at
  end

  test "does not expose another household transaction" do
    other = Account.create!(name: "Hidden household")
    other_account = Financial::Account.create!(account: other, name: "Hidden cash", account_group: "asset", account_type: "checking", status: "active", opening_balance: 0)
    hidden = Financial::Transaction.create!(account: other, destination_account: other_account, transaction_type: "income", transaction_date: Date.current, amount: 10, description: "Hidden")

    get finance_transaction_path(hidden)
    assert_response :not_found
  end
end
