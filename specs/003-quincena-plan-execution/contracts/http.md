# HTTP Contract: Financial Plan Execution

The application remains server-rendered HTML with Turbo-compatible responses. These contracts describe request behavior, not a JSON API.

## Show a plan in an execution order

```http
GET /finance/plans/:id?order=due_date
GET /finance/plans/:id?order=custom
```

### Authorization

- Load `:id` only from `Financial::Plan.for_account(Current.account)`.
- A plan belonging to another account is not found.

### Order selection

- `order=due_date`: dated movements ascending, then unscheduled movements; ties use saved position then ID.
- `order=custom`: saved position then ID.
- Missing `order`: custom when `plan.custom_ordered?`, otherwise due date.
- Unsupported `order`: use the same default; never interpolate it into SQL.

### Response

- `200 OK` HTML.
- Shows the selected order control state.
- Shows "Projection and plan execution" with Planned and Actual rows and Funding, Consumption, and Plan balance columns.
- Planned Funding uses expected source amounts; Actual Funding uses recorded receipts.
- Planned Consumption uses expenses plus normally neutral movements with Reserve funds enabled; Actual Consumption uses actual expense entries.
- Recalculates every running planned-balance row in the selected order.
- Shows each funding destination on its existing source item rather than in a separate account-summary section.
- Shows a "Funds reserved" badge on every movement with Reserve funds enabled.
- Provides drag-and-drop plus compact up/down icon buttons with movement-specific accessible labels.
- Does not write positions or actual entries.

## Replace a plan's custom movement order

```http
PATCH /finance/plans/:plan_id/planned_transaction_order
```

### Form body

```text
planned_transaction_order[ordered_ids][]=41
planned_transaction_order[ordered_ids][]=18
planned_transaction_order[ordered_ids][]=27
```

The request sends the complete intended order, including applied movements.

### Authorization and validation

- Load `:plan_id` only from `Financial::Plan.for_account(Current.account)`.
- Reject an order when IDs are duplicated.
- Reject an order when any ID belongs to another plan or account.
- Reject an order when any current plan movement is omitted.
- Reject changes when existing plan lifecycle rules make planning immutable.

### Success

- Atomically replace positions with contiguous values beginning at 1.
- Set `custom_ordered=true`.
- Change no amount, due date, status, route, Reserve funds value, planned/actual link, or actual entry field.
- Redirect with `303 See Other` to `/finance/plans/:plan_id?order=custom` and a success notice.

### Failure

- Persist no partial order.
- Redirect with `303 See Other` to the plan's current view and an actionable alert.

## Correct a planned movement route

The existing planned-movement update endpoint remains the edit boundary:

```http
PATCH /finance/plans/:plan_id/planned_transactions/:id
```

### Relevant form body

```text
planned_transaction[source_selection]=asset:12
planned_transaction[destination_selection]=liability:9
```

The fields shown depend on the movement kind: an expense needs a source, a transfer needs source and asset destination, a liability payment needs source and liability destination, and a liability charge needs its liability source.

### Authorization and validation

- Load both plan and movement through `Current.account` and require the movement to belong to the plan.
- Reuse existing account ownership and route-shape validations.
- Reject invalid or incomplete combinations with an actionable alert and no partial update.

### Behavior

- Update only the planned movement's route fields.
- Permit route correction after application while keeping planned amount and due date protections unchanged.
- Never mutate the linked actual entry's source, destination, amount, date, or identity.
- Redirect with `303 See Other` to the plan.

## Apply a planned movement with an actual date

The existing application endpoint remains compatible:

```http
PATCH /finance/planned_transactions/:id/apply
```

### Relevant form body

```text
planned_transaction[entry_date]=2026-09-15
```

### Behavior

- The form preselects `due_date`, then `planned_for`, then the current date.
- A valid user-supplied earlier or later date overrides the default.
- Application creates or reuses the one linked actual entry under the existing idempotency behavior.
- The actual entry stores the selected `entry_date`.
- The planned movement retains its due date and custom position.
- Reapplying never creates a second entry.

## Update Reserve funds

The existing planned-movement update endpoint also owns this planning choice:

```http
PATCH /finance/plans/:plan_id/planned_transactions/:id
```

### Relevant form body

```text
planned_transaction[commits_plan_funds]=1
```

The persisted field remains `commits_plan_funds`; the form label is "Reserve funds."

### Authorization and validation

- Load the account-scoped plan and movement and require their association.
- Accept the change for pending and applied movements while the plan is `draft` or `active`.
- Reject changes for closed or cancelled plans.

### Behavior

- Expenses reduce Planned balance automatically without this option.
- A normally neutral movement reduces Planned Consumption and running Planned balances when enabled and contributes zero when disabled.
- The response shows "Funds reserved" on enabled movement rows.
- Changing the value never mutates the linked actual entry or Actual Consumption.
- Redirect with `303 See Other` to the plan with a success notice or actionable alert.

## Plans overview

```http
GET /finance/plans
GET /finance/plans?month=2026-09&status=active
```

### Response

- `200 OK` HTML.
- Plans remain ordered by their `planned_for` reference date.
- Overview totals apply to the account-scoped, filtered plans shown.
- Labels identify overview expected funding, Planned Consumption, and expected net as forecast figures, not one plan's Planned/Actual summary.
- Filters do not alter plan membership or exclude movements inside a displayed plan.
