# Quickstart: Financial Plan Execution

## Prerequisites

- Ruby 3.4.7
- PostgreSQL available for the configured Rails environments
- Existing project dependencies installed

## Read the feature

```bash
cat specs/003-quincena-plan-execution/spec.md
cat specs/003-quincena-plan-execution/plan.md
cat specs/003-quincena-plan-execution/data-model.md
cat specs/003-quincena-plan-execution/contracts/http.md
```

## Validation sequence

1. Verify the migration and plan ordering domain tests.
2. Verify separate Planned and Actual Funding, Consumption, Plan balance, and Reserve funds tests.
3. Verify order, sort, and compact accessible reorder controls.
4. Verify route display and correction, payment-note, actual-date, and timing presentation.
5. Verify overview calculations remain separate from plan calculations.
6. Complete the manual walkthrough and full checks.

Each behavior change starts with a failing boundary test.

## Focused checks

```bash
bin/rails test test/models/financial/plan_test.rb
bin/rails test test/models/financial/plan
bin/rails test test/models/financial/plans/overview_test.rb
bin/rails test test/models/planned_expense_test.rb
bin/rails test test/models/financial/planned_transaction_test.rb
bin/rails test test/controllers/financial/plans
bin/rails test test/services/financial/planned_transactions/apply_service_test.rb
bin/rails test test/components/ui/button_component_test.rb
```

## Full checks

```bash
bin/rails test
npm run herb:lint
bin/rubocop
bin/brakeman --no-pager
```

## Manual acceptance walkthrough

1. Create or open a plan with a `planned_for` reference date.
2. Add two funding sources with known expected amounts and destinations, including a case where a destination account has a negative current balance.
3. Add pending movements due on different dates, including an expense, liability payment, and transfer.
4. Apply one movement using a date earlier or later than its due date.
5. Confirm "Projection and plan execution" preserves the existing metric-card grid and shows Planned above Actual for Funding, Consumption, and Plan balance.
6. Confirm Planned Funding equals expected source amounts, Planned Consumption includes every expense, and a negative Plan balance remains negative.
7. Confirm Actual Funding equals recorded receipts and Actual Consumption equals both applied movements' expense entries and unplanned actual expenses associated with the plan.
8. Confirm each funding source shows one destination badge and no separate funding-account summary appears.
9. Confirm the applied row retains its due date and shows the actual date with the correct Early, On time, or Late badge.
10. Correct expense, transfer, and liability-payment routes from their existing edit flow; confirm an applied movement's linked actual entry remains unchanged.
11. Confirm an unreserved transfer and liability payment remain neutral in Planned Consumption and running balances.
12. Enable Reserve funds for each neutral movement; confirm Planned Consumption and affected running balances decrease by each planned amount and each row shows "Funds reserved."
13. Apply one reserved movement, toggle Reserve funds while the plan remains active, and confirm its linked actual entry and Actual Consumption remain unchanged.
14. Close or cancel a plan and confirm Reserve funds can no longer be changed.
15. Switch between due-date and custom order and confirm every row balance changes with the displayed sequence while Planned Consumption does not.
16. Reorder pending and applied rows with drag-and-drop and keyboard-accessible icon buttons, reload, and confirm the custom order persists while the linked actual entry is unchanged.
17. Add another movement and confirm it appears last in custom order.
18. Open the plans overview and confirm its forecast totals use the same Reserve funds rule while remaining separate from the selected plan's Planned/Actual summary.

## Expected invariants

- Plan membership never depends on movement or funding dates.
- Planned Funding equals displayed funding-source expected amounts.
- Actual Funding equals displayed recorded funding receipts.
- Planned Consumption includes each expense and each movement with Reserve funds enabled exactly once, including applied movements.
- Unreserved transfers, liability payments, and other neutral movements contribute zero to Planned Consumption.
- Actual Consumption includes each planned or unplanned actual expense associated with the plan exactly once.
- Each Plan balance equals its row's Funding minus Consumption and may be negative.
- Reserve funds changes planned calculations only and remains editable for pending and applied movements while the plan is active.
- Enabled movements show "Funds reserved"; closed and cancelled plans reject reservation changes.
- Reordering changes only plan positions and the custom-order flag.
- Planned route correction never changes a linked actual entry.
- Actual entry dates always remain user-selected ledger facts.
