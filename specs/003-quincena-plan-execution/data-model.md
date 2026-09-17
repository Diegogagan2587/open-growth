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

- Every funding source contributes its `expected_amount` independently to Planned Funding.
- A source contributes its receipt entry amount to Actual Funding only when that receipt exists.
- Financial account `current_balance` is not used for either total, so unrelated or incomplete ledger entries cannot distort the plan.
- Multiple funding sources selecting the same destination contribute independently; they are not deduplicated.
- The source's selected destination asset or liability is displayed on that source item; no origin account is inferred or persisted.

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
- `commits_plan_funds`, presented as Reserve funds
- route foreign keys

**Rules**:

- `position` is custom priority only; it is not due-date order.
- Due-date order is `due_date ASC NULLS LAST`, with stable tie-breaking by `position`, then `id`.
- Expenses consume planned funds automatically whether pending or applied.
- Transfers, liability payments, and other normally neutral movements reduce Planned Consumption only when Reserve funds is enabled.
- Reserve funds remains editable for pending and applied movements while the plan is `draft` or `active`, but not after the plan is `closed` or `cancelled`.
- Changing Reserve funds never changes the linked actual entry or Actual Consumption.
- Enabled rows display a "Funds reserved" badge.
- `notes` communicates limited obligations such as “minimum payment.”
- Source and destination selections remain editable as corrections to the planned record; after application, changing them does not change the linked actual entry.
- Planned amount and due date remain immutable after application under existing historical protections.
- Timing is derived from the linked actual entry:
  - actual date before due date → `early`
  - dates equal → `on_time`
  - actual date after due date → `late`
  - either date absent → no comparison

**Reserve funds state transition**:

```text
reserved=false
    -- enable on active plan --> reserved=true

reserved=true
    -- disable on active plan --> reserved=false

closed or cancelled plan
    -- any attempted change --> rejected
```

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
- Correcting a planned transaction's route changes no entry field.
- Applying defaults `entry_date` from the planned transaction's `due_date`, then `planned_for`, then today; a supplied user date wins.

## Derived Domain Objects

### Financial::Plan::Projection

**Persistence**: none

**Input**:

- one `Financial::Plan`
- requested order: `due_date` or `custom`

**Outputs**:

- expected funding-source contributions
- Planned Funding
- Planned Consumption
- Planned Plan balance
- completeness state and reasons
- ordered rows containing the planned transaction, its planned cash effect, and running planned balance

**Equations**:

```text
planned_funding = sum(funding source expected amounts)
planned_consumption = sum(planned movement amounts where reduces_plan_balance is true)
planned_balance = planned_funding - planned_consumption

running[0] = planned_funding
running[n] = running[n-1] - planned_amount(row[n]) when reduces_plan_balance is true
```

`reduces_plan_balance` is true for expenses and for any movement with Reserve funds enabled. Pending and applied qualifying rows deduct their planned amount once. Unreserved transfers, liability payments, and other neutral rows deduct zero. A negative running or final balance remains negative.

**Completeness**:

- No funding source: Planned Funding is zero and the projection identifies missing funding-source selection.
- Missing amount on any row that reduces Planned balance: Planned Consumption, Planned Plan balance, and affected subsequent row balances are incomplete.
- Missing route: the row is incomplete; totals remain numeric only when the movement's cash meaning is still unambiguous.

### Financial::Plan::Actuals

**Persistence**: none

**Input**: one `Financial::Plan`

**Outputs**:

- Actual Funding from `funding_entries`
- Actual Consumption from every expense entry associated with the plan, including entries without a linked planned movement
- Actual Plan balance as Actual Funding minus Actual Consumption

**Change**: preceding-plan carryover is removed from the individual plan calculation. Actual values never replace Planned values.

### Financial::Plans::Overview

**Persistence**: none

**Input**: the account-scoped and currently filtered plans relation

**Outputs**:

- plan count
- expected funding across shown plans
- Planned Consumption across shown plans using the same Reserve funds rule
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

- Add one reversible `custom_ordered` boolean column to `income_events`; existing plan rows receive `false` so their first display uses derived due-date order.
- Reuse the existing `planned_expenses.commits_plan_funds` boolean; no reservation migration or backfill is required.
- Existing positions and all financial records remain unchanged.
- No table rename, backfill query, or destructive migration is required.
