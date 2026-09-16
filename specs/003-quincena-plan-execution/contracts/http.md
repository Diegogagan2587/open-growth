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
- Recalculates every running-balance row in the selected order.
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
- Change no amount, due date, status, route, planned/actual link, or actual entry field.
- Redirect with `303 See Other` to `/finance/plans/:plan_id?order=custom` and a success notice.

### Failure

- Persist no partial order.
- Redirect with `303 See Other` to the plan's current view and an actionable alert.

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

## Plans overview

```http
GET /finance/plans
GET /finance/plans?month=2026-09&status=active
```

### Response

- `200 OK` HTML.
- Plans remain ordered by their `planned_for` reference date.
- Overview totals apply to the account-scoped, filtered plans shown.
- Labels identify overview expected funding, pending requirements, and expected net as forecast figures, not one plan's current available money.
- Filters do not alter plan membership or exclude movements inside a displayed plan.
