# frozen_string_literal: true

require "test_helper"

class Financial::EntryRouteComponentTest < ViewComponent::TestCase
  def setup
    account = accounts(:one)
    @checking = Financial::Asset.create!(account: account, name: "Route Checking", account_type: "checking", status: "active", opening_balance: 0)
    @savings = Financial::Asset.create!(account: account, name: "Route Savings", account_type: "savings", status: "active", opening_balance: 0)
    @card = Financial::Liability.create!(account: account, name: "Route Card", liability_type: "credit_card", status: "active", opening_balance: 0)
  end

  test "renders both sides of a transfer" do
    entry = Financial::Entry.new(entry_type: "transfer", financial_account: @checking, counterparty_financial_account: @savings)

    render_inline(Financial::EntryRouteComponent.new(entry: entry))

    assert_text "Route Checking"
    assert_text "Route Savings"
    assert_selector "a[href='#{Rails.application.routes.url_helpers.finance_financial_account_path(@checking)}']"
    assert_selector "a[href='#{Rails.application.routes.url_helpers.finance_financial_account_path(@savings)}']"
  end

  test "labels detailed liability payment endpoints" do
    entry = Financial::Entry.new(entry_type: "liability_payment", financial_account: @checking, financial_liability: @card)

    render_inline(Financial::EntryRouteComponent.new(entry: entry, detailed: true))

    assert_text "Source"
    assert_text "Destination"
    assert_text "Route Card"
  end
end
