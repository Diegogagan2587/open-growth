# Data Model: Financial Plan Execution

## Aggregate Boundary

`Financial::Plan` is the aggregate root for plan membership and custom movement priority. It does not own actual ledger entries: applying a planned movement creates a linked `Financial::Entry`, whose amount and date remain independent historical facts.

## Persisted Entities

### Financial::Plan

**Table**: `income_events` through the existing subclass

**Existing relevant fields**:

- `description` exposed as `name`
- `expected_date` exposed as `planned_for`
- `lifecycle_status`
- `account_id`
- `budget_period_id`

**New field**:

- `custom_ordered:boolean`, default `false`, null `false`

**Relations**:

- has many `Financial::FundingSource`
- has many `Financial::PlannedTransaction`
- has many actual `Financial::Entry` records through existing relations

**Rules**:

- `planned_for` is required reference information and may order plans; it never filters plan membership.
- A submitted custom order must contain every and only movement currently belonging to the plan, exactly once.
- Custom positions are contiguous positive integers beginning at 1.
- Reordering is allowed for pending and applied planned movements while the plan remains editable; it never updates linked entries.
- New movements append through the existing position callback.

**State transition**:

```text
custom_ordered=false
    -- successful reorder --> custom_ordered=true

custom_ordered=true
    -- later reorder --> custom_ordered=true with new positions
```

Viewing due-date order does not change this state.

### Financial::FundingSource

**Table**: `financial_funding_sources`

**Relevant fields**:

- `financial_plan_id`
- `expected_amount`
- `expected_date`
- `expected_destination_asset_id`
- `expected_destination_liability_id`
- `resolution`

**Execution meaning**:

- Every funding source contributes independently to the plan's opening execution money.
- A source contributes its receipt entry amount when received; otherwise it contributes `expected_amount`.
- Financial account `current_balance` is not used for plan availability, so unrelated or incomplete ledger entries cannot distort the plan.
- Multiple funding sources selecting the same asset contribute each source amount; they are not deduplicated.

### Financial::PlannedTransaction

**Table**: `planned_expenses` through the existing subclass

**Relevant fields**:

- `income_event_id` / `plan`
- `amount`
- `due_date`
- `planned_for`
- `position`
- `execution_status`
- `kind`
- `description`
- `notes`
- route foreign keys

**Rules**:

- `position` is custom priority only; it is not due-date order.
- Due-date order is `due_date ASC NULLS LAST`, with stable tie-breaking by `position`, then `id`.
- Pending outflows and liability payments require cash.
- Applied, cancelled, and skipped rows remain visible but do not contribute to pending required money.
- Transfers and liability charges remain visible but do not reduce aggregate available cash.
- `notes` communicates limited obligations such as “minimum payment.”
- The planned due date remains editable only under existing expectation-edit rules and is immutable after application under current historical protections.
- Timing is derived from the linked actual entry:
  - actual date before due date → `early`
  - dates equal → `on_time`
  - actual date after due date → `late`
  - either date absent → no comparison

### Financial::Entry

**Table**: `financial_entries`

**Relevant fields**:

- `planned_expense_id`
- `entry_date`
- `amount`
- route foreign keys
- `entry_type`

**Rules**:

- The entry remains the actual ledger source of truth.
- Reordering a planned transaction changes no entry field.
- Applying defaults `entry_date` from the planned transaction's `due_date`, then `planned_for`, then today; a supplied user date wins.

## Derived Domain Objects

### Financial::Plan::Projection

**Persistence**: none

**Input**:

- one `Financial::Plan`
- requested order: `due_date` or `custom`

**Outputs**:

- selected account balances
- available money
- pending required money
- expected remainder
- shortfall
- completeness state and reasons
- ordered rows containing the planned transaction, its cash effect, and running remaining money

**Equations**:

```text
available = sum(funding source actual amount when received, otherwise expected amount)
required = sum(pending cash-requiring movement amounts)
remainder = max(available - required, 0)
shortfall = max(required - available, 0)

running[0] = available
running[n] = running[n-1] - cash_consuming_amount(row[n])
```

Applied cash-consuming rows deduct once from the funding-source opening amount. Transfers and other non-cash-consuming rows deduct zero.

**Completeness**:

- No funding source: available is zero and the projection identifies missing funding-source selection.
- Missing amount on any cash-requiring row: required, remainder, shortfall, and affected subsequent row balances are incomplete.
- Missing route: the row is incomplete; totals remain numeric only when the movement's cash meaning is still unambiguous.

### Financial::Plan::Actuals

**Persistence**: none

**Input**: one `Financial::Plan`

**Outputs**: actual funding and consumption from entries linked to that plan only.

**Change**: preceding-plan carryover is removed from the individual plan calculation.

### Financial::Plans::Overview

**Persistence**: none

**Input**: the account-scoped and currently filtered plans relation

**Outputs**:

- plan count
- expected funding across shown plans
- pending cash requirements across shown plans
- expected net position across shown plans

These are forecast/portfolio figures, labeled separately from current-money execution figures on a plan page.

## Ordering Transaction

To preserve the existing unique `(income_event_id, position)` index:

1. Scope and lock the plan.
2. Compare submitted IDs with the plan's IDs; reject missing, duplicate, foreign, or extra IDs.
3. Assign unique temporary negative positions.
4. Assign final positions `1..n` in submitted order.
5. Set `custom_ordered=true`.
6. Commit once; any failure rolls back every position.

## Migration Impact

- Add one reversible boolean column to `income_events`.
- Existing rows receive `false`, so their first display uses derived due-date order.
- Existing positions and all financial records remain unchanged.
- No table rename, backfill query, or destructive migration is required.
