require "test_helper"

class Financial::LiabilityTest < ActiveSupport::TestCase
  def setup
    @account = Account.create!(name: "Tenant Account")
    Current.account = @account
    @category = Category.create!(account: @account, name: "Liability test")
  end

  def teardown
    Current.account = nil
  end

  test "calculates current balance from liability entries" do
    liability = Financial::Liability.create!(
      account: @account,
      name: "Card A",
      liability_type: "credit_card",
      status: "active",
      opening_balance: 200
    )

    Financial::Entry.create!(
      account: @account,
      financial_liability: liability,
      entry_type: "liability_charge",
      entry_date: Date.current,
      amount: 80,
      description: "Groceries",
      category: @category
    )

    Financial::Entry.create!(
      account: @account,
      financial_liability: liability,
      financial_account: Financial::Asset.create!(
        account: @account,
        name: "Debit",
        account_type: "debit",
        status: "active",
        opening_balance: 0
      ),
      entry_type: "liability_payment",
      entry_date: Date.current,
      amount: 50,
      description: "Payment"
    )

    assert_equal 230.to_d, liability.current_balance
  end

  test "applies loan disbursement deltas for both origin and destination liabilities" do
    origin = Financial::Liability.create!(
      account: @account,
      name: "Origin Loan",
      liability_type: "personal_credit",
      status: "active",
      opening_balance: 0
    )
    destination = Financial::Liability.create!(
      account: @account,
      name: "Old Loan",
      liability_type: "personal_credit",
      status: "active",
      opening_balance: 500
    )

    Financial::Entry.create!(
      account: @account,
      financial_liability: origin,
      counterparty_financial_liability: destination,
      entry_type: "loan_disbursement",
      entry_date: Date.current,
      amount: 200,
      description: "Refinance"
    )

    assert_equal 200.to_d, origin.current_balance
    assert_equal 300.to_d, destination.current_balance
  end
end
