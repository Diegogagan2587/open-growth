# frozen_string_literal: true

require "test_helper"

class Financial::TransactionRouteComponentTest < ViewComponent::TestCase
  def setup
    account = accounts(:one)
    @checking = Financial::Account.create!(account: account, name: "Route Checking", account_group: "asset", account_type: "checking", status: "active", opening_balance: 0)
    @savings = Financial::Account.create!(account: account, name: "Route Savings", account_group: "asset", account_type: "savings", status: "active", opening_balance: 0)
    @card = Financial::Account.create!(account: account, name: "Route Card", account_group: "liability", account_type: "credit_card", status: "active", opening_balance: 0)
  end

  test "renders both sides of a transfer" do
    transaction = Financial::Transaction.new(transaction_type: "transfer", source_account: @checking, destination_account: @savings)

    render_inline(Financial::TransactionRouteComponent.new(transaction: transaction))

    assert_text "Route Checking"
    assert_text "Route Savings"
    assert_selector "a[href='#{Rails.application.routes.url_helpers.finance_account_path(@checking)}']"
    assert_selector "a[href='#{Rails.application.routes.url_helpers.finance_account_path(@savings)}']"
  end

  test "labels detailed liability payment endpoints" do
    transaction = Financial::Transaction.new(transaction_type: "debt_payment", source_account: @checking, destination_account: @card)

    render_inline(Financial::TransactionRouteComponent.new(transaction: transaction, detailed: true))

    assert_text "Source"
    assert_text "Destination"
    assert_text "Route Card"
  end
end
