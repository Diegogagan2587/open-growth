# Implementation Plan: Financial Plan Execution

**Branch**: `003-quincena-plan-execution` | **Date**: 2026-09-16 | **Spec**: [spec.md](spec.md)

**Input**: Feature specification from `/specs/003-quincena-plan-execution/spec.md`

## Summary

Extend the existing financial-plan implementation so one plan is an unrestricted grouping of funding and planned movements, with `planned_for` retained only as reference information. Restore the compact "Projection and plan execution" metric-card grid with Planned values prominent and Actual values below: planned values use expected funding, expenses, and neutral movements explicitly marked Reserve funds, while actual values use recorded funding receipts and applied movements' actual entries. Keep routes, reservation state, payment timing, and running planned balances visible in due-date or persisted custom order. Preserve existing tables and planned/actual links; reuse the existing `commits_plan_funds` field behind the clearer Reserve funds label, keep plan-owned calculations under `Financial::Plan::*`, collection-wide calculations in `Financial::Plans::Overview`, and atomic priority updates in the focused order resource.

## Technical Context

**Language/Version**: Ruby 3.4.7, Rails 8.1.3

**Primary Dependencies**: Active Record, PostgreSQL, Hotwire/Turbo, Stimulus, ViewComponent, Tailwind CSS

**Storage**: PostgreSQL; existing `income_events`, `planned_expenses`, `financial_funding_sources`, `financial_accounts`, and `financial_entries` tables

**Testing**: Minitest, Rails controller/integration tests, ViewComponent tests, Capybara system tests only where interaction cannot be covered lower

**Target Platform**: Server-rendered Rails web application

**Project Type**: Monolithic Rails web application

**Performance Goals**: Render and reorder a personal plan containing up to 200 movements without perceptible interaction delay; perform one atomic database update for each submitted order

**Constraints**: Preserve existing financial records and actual transaction dates; use decimal-backed money; no new dependency; preserve account scoping; retain legacy table inheritance while the application is transitioning from `IncomeEvent` and `PlannedExpense`

**Scale/Scope**: One plan page, the plans overview, one ordering endpoint, one reversible migration, plan-owned calculations, existing application flow, and focused tests

## Constitution Check

*GATE: Must pass before Phase 0 research. Re-checked after Phase 1 design.*

- **Financial correctness**: PASS. Expected and received funding remain separate, one domain predicate determines whether a planned movement consumes or reserves plan funds, actual accounting remains independent, money remains decimal, planned and actual dates/routes remain distinct, and reorder writes are transactional.
- **Rich Rails-native domain model**: PASS. `Financial::Plan` protects ordering, `Financial::Plan::Projection` owns plan calculations, and `Financial::PlannedTransaction` owns timing and route semantics. No mandatory service layer is added.
- **Resource-oriented interfaces**: PASS. Reordering is represented by a singular nested order resource. Due-date/custom viewing remains a query on `PlansController#show` because it changes no resource state.
- **Boundary tests**: PASS. Model/domain-object tests cover financial rules; controller tests cover order and sort requests; component/view tests cover visible routes and timing; one system test is reserved for the interactive reorder control if lower-level coverage cannot prove it.
- **Accessible component UI**: PASS. Existing button, badge, input, and select components are reused. Compact icon buttons retain movement-specific accessible labels, and drag-and-drop remains an enhancement rather than the only reorder mechanism.
- **Rails-native evolutionary design**: PASS. Existing records, relations, current-balance behavior, position column, unique index, Turbo, and Stimulus are reused. No repository layer, event bus, new framework, or sortable package is introduced.
- **Data safety and authorization**: PASS. Every plan and movement lookup remains scoped through `Current.account`; order payloads must exactly match the plan's movement IDs before positions change.

No constitutional exceptions are required.

## Project Structure

### Documentation (this feature)

```text
specs/003-quincena-plan-execution/
├── plan.md
├── research.md
├── data-model.md
├── quickstart.md
├── contracts/
│   └── http.md
└── tasks.md
```

### Source Code (repository root)

```text
app/
├── components/ui/
│   └── button_component.rb
├── controllers/financial/
│   ├── plans_controller.rb
│   └── plans/
│       └── planned_transaction_orders_controller.rb
├── models/
│   ├── planned_expense.rb
│   └── financial/
│       ├── plan.rb
│       ├── planned_transaction.rb
│       ├── plan/
│       │   ├── actuals.rb
│       │   └── projection.rb
│       └── plans/
│           └── overview.rb
├── components/financial/
│   └── installment_payment_form_component.rb
├── javascript/controllers/
│   └── planned_transaction_order_controller.js
└── views/financial/plans/
    ├── index.html.erb
    ├── show.html.erb
    ├── _metrics.html.erb
    └── _planned_transactions.html.erb

config/
└── routes.rb

db/
└── migrate/
    └── *_add_custom_ordered_to_income_events.rb

test/
├── components/ui/
│   └── button_component_test.rb
├── controllers/financial/
│   ├── plans_controller_test.rb
│   └── plans/planned_transaction_orders_controller_test.rb
├── models/
│   ├── planned_expense_test.rb
│   └── financial/
│       ├── plan_test.rb
│       ├── planned_transaction_test.rb
│       ├── plan/projection_test.rb
│       ├── plan/actuals_test.rb
│       └── plans/overview_test.rb
├── components/financial/
│   └── installment_payment_form_component_test.rb
└── system/
    └── financial_plan_execution_test.rb
```

**Structure Decision**: Keep persisted entities at their existing `Financial::*` level because they are shared with legacy and loan workflows. Nest only behavior owned by one plan (`Financial::Plan::Projection`, `Financial::Plan::Actuals`) and collection behavior (`Financial::Plans::Overview`). Add one focused HTTP controller for the mutable order resource. Do not introduce a `Plan::PlannedTransaction` alias, duplicate model, or new table merely to mirror folders.

## Implementation Strategy

### Slice 1: Correct the execution calculation

1. Move the existing flat plan calculators to Rails-autoloadable plan namespaces and update all callers and tests.
2. Define Planned Funding as the sum of funding sources' expected amounts and Actual Funding as the sum of their recorded receipt entries. Never read account `current_balance` for either value.
3. Define Planned Consumption through one movement predicate: expenses reduce the plan automatically; transfers, liability payments, and other normally neutral movements reduce it only when the existing `commits_plan_funds` value is enabled. Applied planned movements keep the same planned treatment. Actual Consumption continues to follow actual entry accounting and ignores this planning-only choice.
4. Calculate each Plan balance directly as Funding minus Consumption and preserve negative values instead of converting them into a separate remainder or shortfall label.
5. Calculate running rows from Planned Funding, deducting each movement for which the same plan-balance predicate is true once in the requested order so custom and due-date views produce their own sequence without changing totals.
6. Make incomplete route or amount data explicit and mark affected Planned values incomplete rather than substituting zero. Current validations still prevent new amountless records; the display remains defensive for legacy data.

### Slice 2: Persist and expose execution priority

1. Add `income_events.custom_ordered`, default `false`, null-protected. This records whether a plan has an intentional custom order while preserving every existing position.
2. Add `Financial::Plan#reorder_planned_transactions!`. Validate that the submitted IDs are unique and exactly equal the plan's movement IDs, lock the plan, assign temporary negative positions, then assign final positive positions and set `custom_ordered` in one transaction.
3. Add a singular nested planned-transaction-order resource with only `update`. It loads the plan through `Current.account`, invokes the plan method, and redirects back to custom order.
4. Default to due-date order while `custom_ordered` is false. Once reordered, default to custom order. `?order=due_date` and `?order=custom` switch the view without changing positions or the flag.
5. Reuse the existing append callback so new movements are appended to the saved custom sequence. Keep native drag-and-drop and replace full-text move controls with the existing icon-sized button style, inline arrow SVGs, and movement-specific accessible labels. Add only the minimal `aria_label` support to the canonical button component if needed.

### Slice 3: Expose routes, dates, and timing

1. Render each movement's existing route information, with explicit missing-source or missing-destination text when the route is incomplete.
2. Expose the existing `notes` field as an optional payment note for meanings such as “minimum payment”; do not add a one-use classification column.
3. Change the apply form and apply service default date precedence to `due_date`, then `planned_for`, then `Date.current`; continue accepting an earlier or later user-selected date.
4. Add planned-transaction timing behavior that compares the preserved due date with the linked entry's actual date and returns early, on-time, late, or no comparison.
5. Show planned due date, actual date, execution status, and timing badge independently. Reordering never writes to `financial_entries`.
6. Add source and destination selectors to the existing planned-movement edit flow. Route corrections update only the planned record, including after application, and never rewrite the linked actual entry; amount and due-date historical protections remain unchanged.
7. Preserve `commits_plan_funds` as persisted state but present it as "Reserve funds." Offer it for normally neutral movements, keep it editable for pending and applied movements while the plan remains editable (`draft` or `active`), block changes on `closed` or `cancelled` plans through existing lifecycle validation, and show a "Funds reserved" badge on enabled rows.

### Slice 4: Separate overview and plan presentation

1. Make `Financial::Plan::Actuals` plan-local by removing preceding-plan carryover and calculating Actual Funding from funding receipts and Actual Consumption from every expense entry associated with the plan, including unplanned actuals without a linked planned movement.
2. Move collection-wide expected funding, Planned Consumption, and net position to `Financial::Plans::Overview`, calculated for the plans relation currently shown on the index and using the same plan-balance predicate as individual plans.
3. Preserve the existing metric-card grid under "Projection and plan execution" with Funding, Consumption, and Plan balance cards; show Planned prominently and Actual below without introducing a table.
4. Remove the added funding-account summary block. Add one compact destination badge to each existing funding-source item so routing context stays where the source is already displayed.
5. Keep `PlansController#show` as one page request with partials. The sections do not yet have independent loading, authorization, or lifecycle needs, so Turbo Frames with `src` and additional controllers would add no value.
6. Keep `planned_for` visible and retain chronological overview ordering, but remove any implication that it limits plan membership or calculations.

## Verification Strategy

1. Write focused failing tests before each domain change.
2. Run namespace/calculation tests: `bin/rails test test/models/financial/plan test/models/financial/plans/overview_test.rb`.
3. Run ordering and request tests: `bin/rails test test/models/financial/plan_test.rb test/controllers/financial/plans`.
4. Run reservation, route, application-date, and component tests: `bin/rails test test/models/planned_expense_test.rb test/models/financial/planned_transaction_test.rb test/services/financial/planned_transactions/apply_service_test.rb test/components/financial/installment_payment_form_component_test.rb test/components/ui/button_component_test.rb`.
5. Run the focused system test only if Stimulus behavior cannot be fully covered at lower boundaries.
6. Run the full suite: `bin/rails test`.
7. Run `npm run herb:lint` for modified ERB, `bin/rubocop` for Ruby, and `bin/brakeman --no-pager` because financial ownership boundaries are affected.

## Deferred Work

- Do not rename legacy tables or extract `Financial::Plan` from `IncomeEvent`; that migration is independent of this feature and carries larger data risk.
- Do not nest `Financial::PlannedTransaction` or `Financial::FundingSource` under `Financial::Plan`; both are persisted concepts with existing cross-workflow relationships, not private implementation details of the calculator.
- Do not refactor existing close, cancel, move, receive, or apply custom actions unless a task must touch them for this feature. Their resource-oriented cleanup belongs in separate living specifications.
- Do not add external-bank transfers, refinance recommendations, recurrence, date-range enforcement, or a generic ordering framework.
- Do not rename the persisted `commits_plan_funds` column solely for presentation wording; "Reserve funds" is the user-facing label for that existing state.
