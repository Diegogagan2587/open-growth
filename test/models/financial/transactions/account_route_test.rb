require "test_helper"

class Financial::Transactions::AccountRouteTest < ActiveSupport::TestCase
  setup do
    household = Account.create!(name: "Route household")
    @checking = Financial::Account.create!(account: household, name: "Checking", account_group: "asset", account_type: "checking", status: "active", opening_balance: 0)
    @savings = Financial::Account.create!(account: household, name: "Savings", account_group: "asset", account_type: "savings", status: "active", opening_balance: 0)
    @card = Financial::Account.create!(account: household, name: "Card", account_group: "liability", account_type: "credit_card", status: "active", opening_balance: 0)
    @loan = Financial::Account.create!(account: household, name: "Loan", account_group: "liability", account_type: "personal_credit", status: "active", opening_balance: 0)
  end

  test "classifies every complete actual account route" do
    assert_actual source: nil, destination: @checking, kind: "inflow", transaction_type: "income"
    assert_actual source: nil, destination: @card, kind: "inflow", transaction_type: "income"
    assert_actual source: @checking, destination: nil, kind: "outflow", transaction_type: "expense"
    assert_actual source: @card, destination: nil, kind: "liability_charge", transaction_type: "expense"
    assert_actual source: @checking, destination: @savings, kind: "transfer", transaction_type: "transfer"
    assert_actual source: @checking, destination: @card, kind: "liability_payment", transaction_type: "debt_payment"
    assert_actual source: @card, destination: @checking, kind: "loan_disbursement", transaction_type: "loan_disbursement"
    assert_actual source: @card, destination: @loan, kind: "loan_disbursement", transaction_type: "loan_disbursement"
  end

  test "preserves explicit meanings supported by an inflow route" do
    assert_actual source: nil, destination: @checking, kind: "inflow", transaction_type: "refund", requested_type: "refund"
    assert_actual source: nil, destination: @card, kind: "inflow", transaction_type: "adjustment", requested_type: "adjustment"
  end

  test "replaces an incompatible requested type with the route default" do
    route = actual(source: @checking, destination: @card, transaction_type: "expense")

    assert_equal "liability_payment", route.kind
    assert_equal "debt_payment", route.transaction_type
  end

  test "classifies incomplete outgoing planning routes" do
    assert_planning source: nil, destination: nil, kind: "outflow", transaction_type: "expense"
    assert_planning source: nil, destination: @savings, kind: "transfer", transaction_type: "transfer"
    assert_planning source: nil, destination: @card, kind: "liability_payment", transaction_type: "debt_payment"
    assert_planning source: @card, destination: nil, kind: "liability_charge", transaction_type: "expense"
  end

  test "preserves an explicit planning kind when routing is incomplete" do
    route = planning(source: nil, destination: nil, kind: "liability_charge")

    assert_equal "liability_charge", route.kind
    assert_equal "expense", route.transaction_type
    assert_predicate route, :budget_consuming?
  end

  test "requires planning destinations for transfers and liability payments" do
    transfer = planning(source: @checking, destination: nil, kind: "transfer")

    assert_equal [ "must be selected" ], transfer.validation_errors[:destination_account]
  end

  test "requires complete actual routes according to their requested meaning" do
    income = actual(source: nil, destination: nil, transaction_type: "income")
    expense = actual(source: nil, destination: nil, transaction_type: "expense")

    assert_equal [ "must be selected" ], income.validation_errors[:destination_account]
    assert_equal [ "must be selected" ], expense.validation_errors[:source_account]
  end

  test "rejects identical and unsupported planning routes" do
    identical = actual(source: @checking, destination: @checking)
    unsupported = planning(source: @card, destination: @savings)

    assert_equal [ "must differ from source account" ], identical.validation_errors[:destination_account]
    assert_equal [ "must be blank when the source account is a liability" ], unsupported.validation_errors[:destination_account]
    assert_nil identical.kind
    assert_nil unsupported.kind
  end

  test "rejects accounts outside the Finance account groups" do
    unsupported_account = Struct.new(:id, :account_group, :name).new(100, "investment", "Brokerage")
    route = actual(source: unsupported_account, destination: nil, transaction_type: "expense")

    assert_equal [ "must be an asset or liability account" ], route.validation_errors[:source_account]
    assert_nil route.kind
  end

  test "derives shared transaction vocabularies and behavior" do
    assert_equal %w[income expense transfer debt_payment loan_disbursement adjustment refund], Financial::Transactions::AccountRoute.transaction_types
    assert_equal %w[outflow liability_charge transfer liability_payment], Financial::Transactions::AccountRoute.planning_kinds
    assert_equal %w[income loan_disbursement refund], Financial::Transactions::AccountRoute.funding_transaction_types
    assert_predicate planning(source: @checking, destination: nil), :budget_consuming?
    assert_not planning(source: @checking, destination: @savings).budget_consuming?
  end

  test "snapshots its account route as an immutable value" do
    account_route = actual(source: @checking, destination: @savings)
    @savings.account_group = "liability"

    assert_predicate account_route, :frozen?
    assert_equal "transfer", account_route.kind
    assert_predicate account_route.validation_errors, :frozen?
  end

  private

  def actual(source:, destination:, transaction_type: nil)
    Financial::Transactions::AccountRoute.for_actual(source:, destination:, transaction_type:)
  end

  def planning(source:, destination:, kind: nil)
    Financial::Transactions::AccountRoute.for_planning(source:, destination:, kind:)
  end

  def assert_actual(source:, destination:, kind:, transaction_type:, requested_type: nil)
    account_route = actual(source:, destination:, transaction_type: requested_type)
    assert_equal kind, account_route.kind
    assert_equal transaction_type, account_route.transaction_type
    assert_empty account_route.validation_errors
  end

  def assert_planning(source:, destination:, kind:, transaction_type:)
    account_route = planning(source:, destination:)
    assert_equal kind, account_route.kind
    assert_equal transaction_type, account_route.transaction_type
    assert_empty account_route.validation_errors
  end
end
