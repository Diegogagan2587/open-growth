require "test_helper"

class Finance::PendingExpectationsControllerTest < ActionDispatch::IntegrationTest
  setup do
    @account = accounts(:one)
    @user = users(:one)
    @asset = Financial::Asset.create!(account: @account, name: "Pending checking", account_type: "checking", status: "active")
    @other_asset = Financial::Asset.create!(account: @account, name: "Pending savings", account_type: "savings", status: "active")
    @card = Financial::Liability.create!(account: @account, name: "Pending card", liability_type: "credit_card", status: "active")
    @category = Category.create!(account: @account, name: "Pending category")
    @plan = Financial::Plan.create!(account: @account, name: "Pending plan", planned_for: Date.new(2026, 7, 10), expected_amount: 1, lifecycle_status: "active")
    sign_in_as(@user, @account)
  end

  teardown do
    Current.account = nil
    Current.session = nil
  end

  test "shows all actionable expectation types in planned date order" do
    source = funding_source(description: "Expected salary", date: Date.new(2026, 7, 9), destination: @asset)
    transactions = [
      planned_transaction(description: "Expected groceries", kind: "outflow", date: Date.new(2026, 7, 10), financial_account: @asset, category: @category),
      planned_transaction(description: "Expected card purchase", kind: "liability_charge", date: Date.new(2026, 7, 11), financial_liability: @card, category: @category),
      planned_transaction(description: "Expected transfer", kind: "transfer", date: Date.new(2026, 7, 12), financial_account: @asset, counterparty_financial_account: @other_asset),
      planned_transaction(description: "Expected card payment", kind: "liability_payment", date: Date.new(2026, 7, 13), financial_account: @asset, financial_liability: @card)
    ]

    get finance_pending_expectations_path

    assert_response :success
    descriptions = css_select("article h2").map { |heading| heading.text.strip }
    assert_equal [ source.description, *transactions.map(&:description) ], descriptions
    assert_select "form[action='#{receive_finance_plan_funding_source_path(@plan, source)}']"
    transactions.each { |transaction| assert_select "form[action='#{apply_finance_planned_transaction_path(transaction)}']" }
  end

  test "finance hub links to the pending queue" do
    get finance_path

    assert_response :success
    assert_select "a[href='#{finance_pending_expectations_path}']", text: "Review pending expectations"
  end

  test "excludes resolved closed and other-account expectations" do
    visible = planned_transaction(description: "Still pending", kind: "outflow", date: Date.new(2026, 7, 10), financial_account: @asset, category: @category)
    resolved = planned_transaction(description: "Already applied", kind: "outflow", date: Date.new(2026, 7, 10), financial_account: @asset, category: @category)
    resolved.update!(execution_status: "applied")
    closed_plan = Financial::Plan.create!(account: @account, name: "Closed pending plan", planned_for: Date.new(2026, 7, 10), expected_amount: 1)
    closed = planned_transaction(description: "Closed plan item", kind: "outflow", date: Date.new(2026, 7, 10), plan: closed_plan, financial_account: @asset, category: @category)
    closed.plan.update!(lifecycle_status: "closed")
    other_account = Account.create!(name: "Other pending tenant")
    other_plan = Financial::Plan.create!(account: other_account, name: "Other plan", planned_for: Date.current, expected_amount: 1)
    Financial::PlannedTransaction.create!(account: other_account, plan: other_plan, description: "Other tenant item", amount: 10, kind: "outflow", status: "pending_to_pay", category: Category.create!(account: other_account, name: "Other category"))

    get finance_pending_expectations_path

    assert_response :success
    assert_includes response.body, visible.description
    assert_not_includes response.body, resolved.description
    assert_not_includes response.body, closed.description
    assert_not_includes response.body, "Other tenant item"
  end

  test "filters by involved card movement type and planned dates" do
    matching = planned_transaction(description: "Filtered card charge", kind: "liability_charge", date: Date.new(2026, 7, 15), financial_liability: @card, category: @category)
    planned_transaction(description: "Wrong date", kind: "liability_charge", date: Date.new(2026, 7, 20), financial_liability: @card, category: @category)
    planned_transaction(description: "Wrong type", kind: "liability_payment", date: Date.new(2026, 7, 15), financial_account: @asset, financial_liability: @card)
    planned_transaction(description: "Wrong account", kind: "liability_charge", date: Date.new(2026, 7, 15), financial_liability: Financial::Liability.create!(account: @account, name: "Other card", liability_type: "credit_card", status: "active"), category: @category)

    get finance_pending_expectations_path, params: {
      account_ref: "liability:#{@card.id}",
      movement_type: "liability_charge",
      date_from: "2026-07-14",
      date_to: "2026-07-16"
    }

    assert_response :success
    assert_select "article h2", text: matching.description
    assert_select "article", count: 1
    assert_select "select[name='account_ref'] option[value='liability:#{@card.id}'][selected]"
    assert_select "select[name='movement_type'] option[value='liability_charge'][selected]"
  end

  test "apply and receive return to the filtered queue and create linked entries once" do
    transaction = planned_transaction(description: "Apply from queue", kind: "liability_charge", date: Date.new(2026, 7, 15), financial_liability: @card, category: @category)
    source = funding_source(description: "Receive from queue", date: Date.new(2026, 7, 16), destination: @asset)
    queue_url = finance_pending_expectations_url(account_ref: "liability:#{@card.id}")

    assert_difference("Financial::Entry.count", 1) do
      patch apply_finance_planned_transaction_path(transaction), params: { planned_transaction: { amount: "9.50", entry_date: "2026-07-16" } }, headers: { "HTTP_REFERER" => queue_url }
    end
    assert_redirected_to queue_url
    assert_equal transaction.id, Financial::Entry.order(:id).last.planned_expense_id

    queue_url = finance_pending_expectations_url(movement_type: "inflow")
    assert_difference("Financial::Entry.count", 1) do
      post receive_finance_plan_funding_source_path(@plan, source), params: { funding_source: { amount: "11.00", entry_date: "2026-07-17" } }, headers: { "HTTP_REFERER" => queue_url }
    end
    assert_redirected_to queue_url
    assert_equal source, Financial::Entry.order(:id).last.funding_source
  end

  private

  def funding_source(description:, date:, destination:)
    Financial::FundingSource.create!(
      account: @account,
      financial_plan: @plan,
      description: description,
      expected_amount: 10,
      expected_date: date,
      expected_destination_asset: (destination if destination.is_a?(Financial::Asset)),
      expected_destination_liability: (destination if destination.is_a?(Financial::Liability)),
      kind: "income"
    )
  end

  def planned_transaction(description:, kind:, date:, plan: @plan, **routing)
    Financial::PlannedTransaction.create!(
      account: @account,
      plan: plan,
      description: description,
      amount: 10,
      planned_for: date,
      kind: kind,
      status: "pending_to_pay",
      **routing
    )
  end
end
