require "test_helper"

class Financial::PlansControllerTest < ActionDispatch::IntegrationTest
  setup do
    @user = users(:one)
    @account = accounts(:one)
    @plan = IncomeEvent.create!(
      account: @account,
      description: "Migrated July plan",
      expected_date: Date.new(2026, 7, 15),
      expected_amount: 2_000,
      status: "pending"
    )
    sign_in_as(@user, @account)
  end

  teardown do
    Current.account = nil
    Current.session = nil
  end

  test "existing income event is visible as the same plan id in the dedicated plans UI" do
    get finance_plans_path

    assert_response :success
    assert_select "h1", text: "Financial plans"
    assert_select "a[href='#{finance_pending_expectations_path}']", text: "Pending transactions"
    assert_select "a[href='#{finance_plan_path(@plan)}']", text: /Migrated July plan/
    assert_select "h1", text: /Income Events/, count: 0

    get finance_plan_path(@plan)

    assert_response :success
    assert_select "h1", text: "Migrated July plan"
    assert_select "a[href='#{income_event_path(@plan)}']", count: 0
  end

  test "shows planned and actual execution totals" do
    plan = @plan.becomes(Financial::Plan)
    category = Category.create!(account: @account, name: "Execution bills")
    asset = Financial::Asset.create!(account: @account, name: "Execution checking", account_type: "checking", status: "active", opening_balance: -10_000)
    plan.funding_sources.create!(account: @account, description: "Salary", expected_amount: 2_000, expected_date: plan.planned_for, expected_destination_asset: asset)
    Financial::PlannedTransaction.create!(account: @account, plan:, category:, financial_account: asset, description: "Rent", amount: 700, due_date: Date.new(2026, 7, 20), status: "pending_to_pay")

    get finance_plan_path(plan)

    assert_response :success
    assert_select "h2", text: "Projection and plan execution"
    assert_select "section[aria-labelledby='plan-results-title'] table", count: 0
    assert_select "section[aria-labelledby='plan-results-title']" do
      assert_select "div", text: /Funding.*\$2,000.00.*Actual \$0.00/m
      assert_select "div", text: /Consumption.*\$700.00.*Actual \$0.00/m
      assert_select "div", text: /Plan balance.*\$1,300.00.*Actual \$0.00/m
    end
    assert_select "a[href='#{finance_plan_path(plan, order: "custom")}']", text: "Custom order"
    assert_select "a[href='#{finance_plan_path(plan, order: "due_date")}']", text: "Due-date order"
    assert_select "form[action='#{finance_plan_planned_transaction_order_path(plan)}']"
    assert_select "button[aria-label='Move Rent up']"
    assert_select "#actual-entries-title + p", text: /Planned and unplanned expenses count toward Actual consumption/
  end

  test "shows reserve funds controls and badge for a neutral movement" do
    plan = @plan.becomes(Financial::Plan)
    source = Financial::Asset.create!(account: @account, name: "Reserve source", account_type: "checking", status: "active", opening_balance: 100)
    destination = Financial::Asset.create!(account: @account, name: "Reserve destination", account_type: "savings", status: "active", opening_balance: 0)
    transaction = Financial::PlannedTransaction.create!(account: @account, plan:, financial_account: source, counterparty_financial_account: destination, description: "Reserved transfer", amount: 25, status: "pending_to_pay", commits_plan_funds: true)

    get finance_plan_path(plan)

    assert_select "input[name='planned_transaction[commits_plan_funds]'][type='checkbox']"
    assert_select "tbody", text: /Reserved transfer.*Funds reserved/m
    assert_select "form[action='#{finance_plan_planned_transaction_path(plan, transaction)}']"
  end

  test "shows filtered portfolio overview figures separately" do
    @plan.update!(lifecycle_status: "active")
    august = Financial::Plan.create!(account: @account, name: "August plan", planned_for: Date.new(2026, 8, 1), expected_amount: 1, lifecycle_status: "active")

    get finance_plans_path, params: { month: "2026-07", status: "active" }

    assert_response :success
    assert_select "h2", text: "Plans overview"
    assert_select "dt", text: "Plans shown"
    assert_select "dd", text: "1"
    assert_select "dt", text: "Expected funding"
    assert_select "dt", text: "Planned consumption"
    assert_select "dt", text: "Planned balance"
    assert_select "a[href='#{finance_plan_path(august)}']", count: 0
  end

  test "shows each planned movement account route" do
    plan = @plan.becomes(Financial::Plan)
    source = Financial::Asset.create!(account: @account, name: "Route source", account_type: "checking", status: "active", opening_balance: 100)
    destination = Financial::Asset.create!(account: @account, name: "Route destination", account_type: "savings", status: "active", opening_balance: 0)
    Financial::PlannedTransaction.create!(account: @account, plan:, financial_account: source, counterparty_financial_account: destination, description: "Route transfer", amount: 25, status: "pending_to_pay")

    get finance_plan_path(plan)

    assert_response :success
    assert_select "tbody", text: /Route source → Route destination/
  end

  test "shows each funding destination on its source without a separate summary" do
    plan = @plan.becomes(Financial::Plan)
    asset = Financial::Asset.create!(account: @account, name: "Payroll checking", account_type: "checking", status: "active", opening_balance: 0)
    plan.funding_sources.create!(account: @account, description: "Payroll", expected_amount: 500, expected_date: plan.planned_for, expected_destination_asset: asset)

    get finance_plan_path(plan)

    assert_select "article", text: /Payroll.*Destination: Payroll checking/m
    assert_select "h3", text: "Plan funding", count: 0
  end

  test "corrects an applied planned route without changing the actual entry" do
    plan = @plan.becomes(Financial::Plan)
    source = Financial::Asset.create!(account: @account, name: "Original source", account_type: "checking", status: "active", opening_balance: 100)
    original_destination = Financial::Asset.create!(account: @account, name: "Original destination", account_type: "savings", status: "active", opening_balance: 0)
    corrected_destination = Financial::Asset.create!(account: @account, name: "Corrected destination", account_type: "savings", status: "active", opening_balance: 0)
    transaction = Financial::PlannedTransaction.create!(account: @account, plan:, financial_account: source, counterparty_financial_account: original_destination, description: "Correct route", amount: 25, status: "pending_to_pay")
    entry = Financial::PlannedTransactions::ApplyService.call(planned_transaction: transaction).entry

    patch finance_plan_planned_transaction_path(plan, transaction), params: {
      planned_transaction: {
        source_selection: "asset:#{source.id}",
        destination_selection: "asset:#{corrected_destination.id}"
      }
    }

    assert_redirected_to finance_plan_path(plan)
    assert_equal corrected_destination, transaction.reload.counterparty_financial_account
    assert_equal original_destination, entry.reload.counterparty_financial_account
  end

  test "rejects a planned route account from another household" do
    plan = @plan.becomes(Financial::Plan)
    source = Financial::Asset.create!(account: @account, name: "Owned source", account_type: "checking", status: "active", opening_balance: 100)
    destination = Financial::Asset.create!(account: @account, name: "Owned destination", account_type: "savings", status: "active", opening_balance: 0)
    other_account = Account.create!(name: "Other route household")
    foreign_source = Financial::Asset.create!(account: other_account, name: "Foreign source", account_type: "checking", status: "active", opening_balance: 100)
    transaction = Financial::PlannedTransaction.create!(account: @account, plan:, financial_account: source, counterparty_financial_account: destination, description: "Scoped route", amount: 25, status: "pending_to_pay")

    patch finance_plan_planned_transaction_path(plan, transaction), params: {
      planned_transaction: { source_selection: "asset:#{foreign_source.id}" }
    }

    assert_redirected_to finance_plan_path(plan)
    assert_equal source, transaction.reload.financial_account
    assert_match(/must belong to the current account/, flash[:alert])
  end

  test "shows route correction controls for an applied movement" do
    plan = @plan.becomes(Financial::Plan)
    source = Financial::Asset.create!(account: @account, name: "Edit source", account_type: "checking", status: "active", opening_balance: 100)
    destination = Financial::Asset.create!(account: @account, name: "Edit destination", account_type: "savings", status: "active", opening_balance: 0)
    transaction = Financial::PlannedTransaction.create!(account: @account, plan:, financial_account: source, counterparty_financial_account: destination, description: "Edit applied route", amount: 25, status: "pending_to_pay")
    Financial::PlannedTransactions::ApplyService.call(planned_transaction: transaction)

    get finance_plan_path(plan)

    assert_select "form[action='#{finance_plan_planned_transaction_path(plan, transaction)}']" do
      assert_select "select[name='planned_transaction[source_selection]']"
      assert_select "select[name='planned_transaction[destination_selection]']"
    end
  end

  test "renders long plan dates in Spanish" do
    @user.update!(locale: "es")

    get finance_plans_path

    assert_response :success
    assert_includes response.body, "15 de Julio de 2026"
    assert_select "a[href='#{finance_pending_expectations_path}']", text: "Transacciones pendientes"
  end

  test "filters plans by month and lifecycle status" do
    @plan.update!(lifecycle_status: "active")
    closed_july = Financial::Plan.create!(account: @account, name: "Closed July plan", planned_for: Date.new(2026, 7, 20), expected_amount: 1, lifecycle_status: "closed")
    active_august = Financial::Plan.create!(account: @account, name: "Active August plan", planned_for: Date.new(2026, 8, 1), expected_amount: 1, lifecycle_status: "active")

    get finance_plans_path, params: { month: "2026-07", status: "active" }

    assert_response :success
    assert_select "form[action='#{finance_plans_path}'][method='get']"
    assert_select "input[name='month'][type='month'][value='2026-07']"
    assert_select "select[name='status'] option[selected][value='active']", text: "Active"
    assert_select "a[href='#{finance_plan_path(@plan)}']", text: @plan.description
    assert_select "a[href='#{finance_plan_path(closed_july)}']", count: 0
    assert_select "a[href='#{finance_plan_path(active_august)}']", count: 0
    assert_select "h2", text: "Plans overview"
    assert_select "dt", text: "Plans shown"
    assert_select "dd", text: "1"
    assert_select "p", text: /Forecast for the plans shown/
  end

  test "creates a plan and its initial funding source through the plans workflow" do
    asset = Financial::Asset.create!(
      account: @account,
      name: "Plan checking",
      account_type: "checking",
      status: "active",
      opening_balance: 0
    )

    get new_finance_plan_path
    assert_response :success
    assert_select "form[action='#{finance_plans_path}'][method='post']"

    assert_difference([ "Financial::Plan.count", "Financial::FundingSource.count" ], 1) do
      post finance_plans_path, params: {
        financial_plan: {
          name: "August household plan",
          planned_for: "2026-08-01",
          lifecycle_status: "draft"
        },
        financial_funding_source: {
          description: "Salary",
          expected_amount: "2500.00",
          expected_date: "2026-08-01",
          kind: "income",
          expected_destination_asset_id: asset.id
        }
      }
    end

    created_plan = Financial::Plan.order(:id).last
    assert_redirected_to finance_plan_path(created_plan)
    assert_equal "August household plan", created_plan.name
    assert_equal 1, created_plan.funding_sources.count
    assert_equal 2_500.to_d, created_plan.funding_sources.first.expected_amount
  end

  test "adds and receives funding without changing its expected values" do
    asset = Financial::Asset.create!(account: @account, name: "Receipt checking", account_type: "checking", status: "active", opening_balance: 0)

    assert_difference("Financial::FundingSource.count", 1) do
      post finance_plan_funding_sources_path(@plan), params: {
        funding_source: {
          description: "Freelance payment",
          expected_amount: "600.00",
          expected_date: "2026-07-15",
          kind: "income",
          expected_destination_asset_id: asset.id
        }
      }
    end

    source = Financial::FundingSource.order(:id).last
    assert_redirected_to finance_plan_path(@plan)

    assert_difference("Financial::Entry.count", 1) do
      post receive_finance_plan_funding_source_path(@plan, source), params: {
        funding_source: { amount: "575.00", entry_date: "2026-07-16" }
      }
    end

    assert_redirected_to finance_plan_path(@plan)
    assert_equal 600.to_d, source.reload.expected_amount
    assert_equal 575.to_d, source.actual_amount
    assert_equal "closed_with_variance", source.resolution
  end

  test "adds and applies a planned transaction while preserving the expectation" do
    category = Category.create!(account: @account, name: "Plan groceries")
    asset = Financial::Asset.create!(account: @account, name: "Spending checking", account_type: "checking", status: "active", opening_balance: 0)

    assert_difference("Financial::PlannedTransaction.count", 1) do
      post finance_plan_planned_transactions_path(@plan), params: {
        planned_transaction: {
          description: "Groceries",
          amount: "100.00",
          planned_for: "2026-07-15",
          due_date: "2026-07-15",
          kind: "outflow",
          importance: "essential",
          category_id: category.id,
          financial_account_id: asset.id
        }
      }
    end

    transaction = Financial::PlannedTransaction.order(:id).last
    assert_redirected_to finance_plan_path(@plan)

    assert_difference("Financial::Entry.count", 1) do
      patch apply_finance_planned_transaction_path(transaction), params: {
        planned_transaction: { amount: "92.00", entry_date: "2026-07-16" }
      }, headers: { "HTTP_REFERER" => finance_plan_url(@plan) }
    end

    assert_redirected_to finance_plan_path(@plan)
    assert_equal 100.to_d, transaction.reload.amount
    assert_equal "applied", transaction.execution_status
    assert_equal 92.to_d, transaction.financial_entry.amount

    get finance_plan_path(@plan)
    assert_select "tbody", text: /Paid 2026-07-16.*Late/m
  end

  test "corrects an applied liability payment commitment without changing its actual entry" do
    asset = Financial::Asset.create!(account: @account, name: "Commitment checking", account_type: "checking", status: "active", opening_balance: 500)
    liability = Financial::Liability.create!(account: @account, name: "Commitment card", liability_type: "credit_card", status: "active", opening_balance: 125)
    transaction = Financial::PlannedTransaction.create!(
      account: @account,
      plan: @plan.becomes(Financial::Plan),
      description: "Pay commitment card",
      amount: 125,
      status: "pending_to_pay",
      financial_account: asset,
      financial_liability: liability
    )
    result = Financial::PlannedTransactions::ApplyService.call(planned_transaction: transaction)
    entry = result.entry

    patch finance_plan_planned_transaction_path(@plan, transaction), params: {
      planned_transaction: { commits_plan_funds: "1", description: "Changed history" }
    }

    assert_redirected_to finance_plan_path(@plan)
    assert transaction.reload.commits_plan_funds?
    assert_equal "Pay commitment card", transaction.description
    assert_equal 125.to_d, Financial::Plan::Projection.for(@plan).planned_consumption
    assert_equal "Pay commitment card", entry.reload.description
    assert_equal 125.to_d, entry.amount

    patch finance_plan_planned_transaction_path(@plan, transaction), params: {
      planned_transaction: { commits_plan_funds: "0" }
    }

    assert_not transaction.reload.commits_plan_funds?
    assert_equal 0.to_d, Financial::Plan::Projection.for(@plan).planned_consumption
  end

  test "does not edit commitments for non-applied transactions or finalized plans" do
    asset = Financial::Asset.create!(account: @account, name: "Locked checking", account_type: "checking", status: "active", opening_balance: 500)
    liability = Financial::Liability.create!(account: @account, name: "Locked card", liability_type: "credit_card", status: "active", opening_balance: 125)
    %w[cancelled skipped].each do |execution_status|
      transaction = Financial::PlannedTransaction.create!(
        account: @account,
        plan: @plan.becomes(Financial::Plan),
        description: "#{execution_status.humanize} payment",
        amount: 25,
        status: "pending_to_pay",
        execution_status: execution_status,
        financial_account: asset,
        financial_liability: liability
      )

      patch finance_plan_planned_transaction_path(@plan, transaction), params: {
        planned_transaction: { commits_plan_funds: "1" }
      }

      assert_not transaction.reload.commits_plan_funds?
      assert_equal "Only pending transactions or applied plan commitments can be edited", flash[:alert]
    end

    applied = Financial::PlannedTransaction.create!(
      account: @account,
      plan: @plan.becomes(Financial::Plan),
      description: "Applied payment",
      amount: 100,
      status: "pending_to_pay",
      financial_account: asset,
      financial_liability: liability
    )
    Financial::PlannedTransactions::ApplyService.call(planned_transaction: applied)
    @plan.update!(lifecycle_status: "closed")

    patch finance_plan_planned_transaction_path(@plan, applied), params: {
      planned_transaction: { commits_plan_funds: "1" }
    }

    assert_not applied.reload.commits_plan_funds?
    assert_equal "Plan must be active before changing planned transactions", flash[:alert]

    get finance_plan_path(@plan)
    assert_select "form[action='#{finance_plan_planned_transaction_path(@plan, applied)}']", count: 0
  end

  test "reserves an applied non-liability transaction without changing its actual entry" do
    category = Category.create!(account: @account, name: "Non-commitment expense")
    asset = Financial::Asset.create!(account: @account, name: "Expense checking", account_type: "checking", status: "active", opening_balance: 100)
    transaction = Financial::PlannedTransaction.create!(
      account: @account,
      plan: @plan.becomes(Financial::Plan),
      category: category,
      description: "Ordinary expense",
      amount: 25,
      status: "pending_to_pay",
      financial_account: asset
    )
    entry = Financial::PlannedTransactions::ApplyService.call(planned_transaction: transaction).entry

    patch finance_plan_planned_transaction_path(@plan, transaction), params: {
      planned_transaction: { commits_plan_funds: "1" }
    }

    assert transaction.reload.commits_plan_funds?
    assert_equal 25.to_d, entry.reload.amount
    assert_equal "Ordinary expense", entry.description
  end

  test "planned transaction form exposes expense or transfer with unified account routing" do
    asset = Financial::Asset.create!(account: @account, name: "Everyday cash", account_type: "checking", status: "active", opening_balance: 0)
    liability = Financial::Liability.create!(account: @account, name: "Rewards card", liability_type: "credit_card", status: "active", opening_balance: 0)

    get finance_plan_path(@plan)

    assert_response :success
    assert_select "select[name='planned_transaction[transaction_type]']" do
      assert_select "option[value='expense']", text: "Expense"
      assert_select "option[value='transfer']", text: "Transfer / payment"
    end
    assert_select "select[name='planned_transaction[source_selection]']" do
      assert_select "option[value='asset:#{asset.id}']"
      assert_select "option[value='liability:#{liability.id}']"
    end
    assert_select "[data-planned-transaction-form-target='destinationFields'] select[name='planned_transaction[destination_selection]']" do
      assert_select "option[value='asset:#{asset.id}']"
      assert_select "option[value='liability:#{liability.id}']"
    end
    assert_select "input[name='planned_transaction[due_date]'][type='date']"
    assert_select "input[name='planned_transaction[notes]']"
    assert_select "select[name='planned_transaction[kind]']", count: 0
    assert_select "select[name='planned_transaction[financial_account_id]']", count: 0
    assert_select "select[name='planned_transaction[financial_liability_id]']", count: 0
  end

  test "move selector shows the transaction's current plan by default" do
    category = Category.create!(account: @account, name: "Move selector category")
    transaction = Financial::PlannedTransaction.create!(
      account: @account,
      plan: @plan.becomes(Financial::Plan),
      description: "Assigned expense",
      amount: 20,
      category: category,
      kind: "outflow",
      status: "pending_to_pay"
    )

    get finance_plan_path(@plan)

    assert_response :success
    assert_select "form[action='#{move_finance_planned_transaction_path(transaction)}'] select[name='target_plan_id']" do
      assert_select "option[selected][value='#{@plan.id}']", text: @plan.description
      assert_select "option[value='']", text: "Unassigned"
    end
  end

  test "expense from a liability becomes a planned liability charge" do
    category = Category.create!(account: @account, name: "Planned utilities")
    liability = Financial::Liability.create!(account: @account, name: "Household card", liability_type: "credit_card", status: "active", opening_balance: 0)

    assert_difference("Financial::PlannedTransaction.count", 1) do
      post finance_plan_planned_transactions_path(@plan), params: {
        planned_transaction: {
          transaction_type: "expense",
          description: "Electric bill",
          amount: "80.00",
          planned_for: "2026-07-15",
          source_selection: "liability:#{liability.id}",
          destination_selection: "asset:999999",
          category_id: category.id
        }
      }
    end

    transaction = Financial::PlannedTransaction.order(:id).last
    assert_redirected_to finance_plan_path(@plan)
    assert_equal "liability_charge", transaction.kind
    assert_equal liability, transaction.financial_liability
    assert_nil transaction.financial_account
    assert_nil transaction.counterparty_financial_account
  end

  test "transfer from an asset to a liability becomes a planned liability payment" do
    asset = Financial::Asset.create!(account: @account, name: "Payment checking", account_type: "checking", status: "active", opening_balance: 0)
    liability = Financial::Liability.create!(account: @account, name: "Payment card", liability_type: "credit_card", status: "active", opening_balance: 0)

    assert_difference("Financial::PlannedTransaction.count", 1) do
      post finance_plan_planned_transactions_path(@plan), params: {
        planned_transaction: {
          transaction_type: "transfer",
          description: "Pay credit card",
          amount: "125.00",
          planned_for: "2026-07-15",
          source_selection: "asset:#{asset.id}",
          destination_selection: "liability:#{liability.id}",
          commits_plan_funds: "1"
        }
      }
    end

    transaction = Financial::PlannedTransaction.order(:id).last
    assert_redirected_to finance_plan_path(@plan)
    assert_equal "liability_payment", transaction.kind
    assert_equal asset, transaction.financial_account
    assert_equal liability, transaction.financial_liability
    assert_nil transaction.category
    assert transaction.commits_plan_funds?

    get finance_plan_path(@plan)
    assert_response :success
    assert_select "section[aria-labelledby='plan-results-title']", text: /Consumption.*\$125.00.*Actual \$0.00/m
    assert_select "tbody", text: /Pay credit card/
  end

  test "expense from an asset becomes a planned outflow" do
    category = Category.create!(account: @account, name: "Planned household")
    asset = Financial::Asset.create!(account: @account, name: "Expense checking", account_type: "checking", status: "active", opening_balance: 0)

    post finance_plan_planned_transactions_path(@plan), params: {
      planned_transaction: {
        transaction_type: "expense",
        description: "Groceries",
        amount: "95.00",
        planned_for: "2026-07-15",
        source_selection: "asset:#{asset.id}",
        category_id: category.id
      }
    }

    transaction = Financial::PlannedTransaction.order(:id).last
    assert_redirected_to finance_plan_path(@plan)
    assert_equal "outflow", transaction.kind
    assert_equal asset, transaction.financial_account
    assert_equal category, transaction.category
  end

  test "transfer between assets becomes a planned transfer" do
    source = Financial::Asset.create!(account: @account, name: "Transfer source", account_type: "checking", status: "active", opening_balance: 0)
    destination = Financial::Asset.create!(account: @account, name: "Transfer destination", account_type: "savings", status: "active", opening_balance: 0)

    post finance_plan_planned_transactions_path(@plan), params: {
      planned_transaction: {
        transaction_type: "transfer",
        description: "Move to savings",
        amount: "200.00",
        planned_for: "2026-07-15",
        source_selection: "asset:#{source.id}",
        destination_selection: "asset:#{destination.id}"
      }
    }

    transaction = Financial::PlannedTransaction.order(:id).last
    assert_redirected_to finance_plan_path(@plan)
    assert_equal "transfer", transaction.kind
    assert_equal source, transaction.financial_account
    assert_equal destination, transaction.counterparty_financial_account
    assert_nil transaction.category
  end

  test "legacy income event pages redirect to the same plan id" do
    get income_events_path
    assert_redirected_to finance_plans_path

    get income_event_path(@plan)
    assert_redirected_to finance_plan_path(@plan)

    get edit_income_event_path(@plan)
    assert_redirected_to edit_finance_plan_path(@plan)
  end

  test "edit form submits to the finance plan route and updates a migrated plan" do
    get edit_finance_plan_path(@plan)

    assert_response :success
    assert_select "form[action='#{finance_plan_path(@plan)}']" do
      assert_select "input[name='_method'][value='patch']"
    end

    patch finance_plan_path(@plan), params: {
      financial_plan: {
        name: "Updated migrated plan",
        planned_for: "2026-07-20",
        lifecycle_status: "active"
      }
    }

    assert_redirected_to finance_plan_path(@plan)
    updated_plan = Financial::Plan.find(@plan.id)
    assert_equal "Updated migrated plan", updated_plan.name
    assert_equal Date.new(2026, 7, 20), updated_plan.planned_for
  end

  test "edits a migrated loan plan without requiring obsolete income event loan routing" do
    legacy_loan_plan = IncomeEvent.new(
      account: @account,
      description: "Legacy loan plan",
      expected_date: Date.new(2026, 9, 1),
      expected_amount: 1_000,
      income_type: "loan",
      loan_amount: 1_000,
      status: "pending"
    )
    legacy_loan_plan.save!(validate: false)

    patch finance_plan_path(legacy_loan_plan), params: {
      financial_plan: {
        name: "Updated loan plan",
        planned_for: "2026-09-02",
        lifecycle_status: "active"
      }
    }

    assert_redirected_to finance_plan_path(legacy_loan_plan)
    assert_equal "Updated loan plan", Financial::Plan.find(legacy_loan_plan.id).name
  end

  test "edit can repair a migrated cross-account budget period" do
    other_account = Account.create!(name: "Other plan tenant")
    foreign_period = BudgetPeriod.create!(account: other_account, name: "Foreign period", start_date: Date.new(2026, 7, 1), end_date: Date.new(2026, 7, 31))
    @plan.update_column(:budget_period_id, foreign_period.id)

    patch finance_plan_path(@plan), params: {
      financial_plan: {
        name: "Repaired plan",
        planned_for: "2026-07-15",
        budget_period_id: "",
        lifecycle_status: "active"
      }
    }

    assert_redirected_to finance_plan_path(@plan)
    assert_nil Financial::Plan.find(@plan.id).budget_period
  end
end
