require "test_helper"

class Financial::Transactions::AccountRouteTest < ActiveSupport::TestCase
  Endpoint = Struct.new(:id, :account_group, :name, keyword_init: true)

  setup do
    @checking = Endpoint.new(id: 1, account_group: "asset", name: "Checking")
    @savings = Endpoint.new(id: 2, account_group: "asset", name: "Savings")
    @card = Endpoint.new(id: 3, account_group: "liability", name: "Card")
    @loan = Endpoint.new(id: 4, account_group: "liability", name: "Loan")
  end

  test "classifies an income route" do
    # Arrange
    destination = @checking

    # Act
    route = Financial::Transactions::AccountRoute.for_actual(source: nil, destination:)

    # Assert
    assert_equal "inflow", route.kind
    assert_equal "income", route.transaction_type
    assert_empty route.validation_errors
  end

  test "classifies an asset to asset route as a transfer" do
    # Arrange
    source = @checking
    destination = @savings

    # Act
    route = Financial::Transactions::AccountRoute.for_actual(source:, destination:)

    # Assert
    assert_equal "transfer", route.kind
    assert_equal "transfer", route.transaction_type
    assert_empty route.validation_errors
  end

  test "classifies a liability payment route" do
    # Arrange
    source = @checking
    destination = @card

    # Act
    route = Financial::Transactions::AccountRoute.for_actual(source:, destination:)

    # Assert
    assert_equal "liability_payment", route.kind
    assert_equal "debt_payment", route.transaction_type
    assert_empty route.validation_errors
  end

  test "classifies an incomplete planning route" do
    # Arrange
    destination = @savings

    # Act
    # Planned income and loan funding are represented by funding sources.
    # Therefore, a planning route with only an asset destination is treated
    # as an incomplete transfer route rather than as an inflow.
    route = Financial::Transactions::AccountRoute.for_planning(source: nil, destination:)

    # Assert
    assert_equal "transfer", route.kind
    assert_equal "transfer", route.transaction_type
    assert_empty route.validation_errors
  end

  test "classifies a planned outflow when its destination is not selected yet" do
    # Arrange
    source = @checking

    # Act
    route = Financial::Transactions::AccountRoute.for_planning(
      source: source,
      destination: nil
    )

    # Assert
    assert_equal "outflow", route.kind
    assert_equal "expense", route.transaction_type
    assert_empty route.validation_errors
  end

  test "preserves an explicitly requested refund meaning" do
    # Arrange
    destination = @checking

    # Act
    route = Financial::Transactions::AccountRoute.for_actual(
      source: nil,
      destination:,
      transaction_type: "refund"
    )

    # Assert
    assert_equal "inflow", route.kind
    assert_equal "refund", route.transaction_type
    assert_empty route.validation_errors
  end

  test "rejects identical accounts" do
    # Arrange
    source = @checking
    destination = @checking

    # Act
    route = Financial::Transactions::AccountRoute.for_actual(
      source:,
      destination:
    )

    # Assert
    assert_nil route.kind
    assert_equal [ "must differ from source account" ], route.validation_errors[:destination_account]
  end

  test "rejects accounts outside the supported groups" do
    # Arrange
    source = Endpoint.new(id: 5, account_group: "investment", name: "Brokerage")

    # Act
    route = Financial::Transactions::AccountRoute.for_actual(source:, destination: nil)

    # Assert
    assert_nil route.kind
    assert_equal [ "must be an asset or liability account" ], route.validation_errors[:source_account]
  end

  test "exposes stable vocabularies and routing summaries" do
    # Arrange
    source = @checking
    destination = @savings

    # Act
    transfer = Financial::Transactions::AccountRoute.for_actual(source:, destination:)
    planning_expense = Financial::Transactions::AccountRoute.for_planning(source:, destination: nil)

    # Assert
    assert_equal %w[income expense transfer debt_payment loan_disbursement adjustment refund], Financial::Transactions::AccountRoute.transaction_types
    assert_equal %w[outflow liability_charge transfer liability_payment], Financial::Transactions::AccountRoute.planning_kinds
    assert_equal %w[income loan_disbursement refund], Financial::Transactions::AccountRoute.funding_transaction_types
    assert_equal "Transfer from Checking to Savings", transfer.routing_summary
    assert_predicate planning_expense, :budget_consuming?
  end
end
