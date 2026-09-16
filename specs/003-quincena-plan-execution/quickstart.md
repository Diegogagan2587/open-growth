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
2. Verify current-balance, pending-only projection tests.
3. Verify order and sort request tests.
4. Verify route, payment-note, actual-date, and timing presentation.
5. Verify overview calculations remain separate from plan calculations.
6. Complete the manual walkthrough and full checks.

Each behavior change starts with a failing boundary test.

## Focused checks

```bash
bin/rails test test/models/financial/plan_test.rb
bin/rails test test/models/financial/plan
bin/rails test test/models/financial/plans/overview_test.rb
bin/rails test test/controllers/financial/plans
bin/rails test test/services/financial/planned_transactions/apply_service_test.rb
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
2. Add two funding sources with known expected amounts, including a case where a selected account has a negative current balance.
3. Add pending movements due on different dates, including a liability payment and a transfer.
4. Apply one movement using a date earlier or later than its due date.
5. Confirm the plan shows each selected account balance, their exact total, pending required money, remainder or shortfall, routes, and no second deduction for the applied movement.
6. Confirm the applied row retains its due date and shows the actual date with the correct Early, On time, or Late badge.
7. Switch between due-date and custom order and confirm every row balance changes with the displayed sequence while totals do not.
8. Reorder pending and applied rows, reload, and confirm the custom order persists while the linked actual entry is unchanged.
9. Add another movement and confirm it appears last in custom order.
10. Open the plans overview and confirm its forecast totals are clearly separate from the selected plan's current-money calculation.

## Expected invariants

- Plan membership never depends on movement or funding dates.
- Current available money equals the sum of displayed selected-account balances.
- Pending required money equals displayed pending cash-requiring movements.
- Applied actual effects are not deducted twice.
- Reordering changes only plan positions and the custom-order flag.
- Actual entry dates always remain user-selected ledger facts.
