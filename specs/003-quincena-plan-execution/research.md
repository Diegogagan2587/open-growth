# Research: Financial Plan Execution

## 1. Evolve the current implementation

**Decision**: Extend the existing `Financial::Plan`, `Financial::PlannedTransaction`, `Financial::FundingSource`, `Financial::Entry`, and position-based ordering instead of creating replacement tables or a parallel domain.

**Rationale**: The current implementation already preserves planned/actual identity, account routes, current balances, and a unique position per plan. Reusing those guarantees produces a smaller and safer financial migration.

**Alternatives rejected**:

- New plan and movement tables: duplicates live financial data and requires a risky cutover.
- A generic planning engine: no current requirement outside financial plans.
- A repository/application-service layer: Rails and Active Record already express the required transaction and ownership boundaries.

## 2. Namespace only plan-owned behavior

**Decision**: Use `Financial::Plan::Projection` and `Financial::Plan::Actuals` for behavior owned by one plan, and `Financial::Plans::Overview` for collection-wide calculations. Keep `Financial::PlannedTransaction` and `Financial::FundingSource` as top-level persisted entities.

**Rationale**: Folder structure should communicate ownership, not force every association into the aggregate root's namespace. A plan projection cannot exist meaningfully without one plan; a planned transaction remains a persisted record referenced by actual entries, loans, pending-expectation screens, and legacy workflows.

**37signals reference**: Basecamp's Fizzy keeps entity models such as `Card` top-level while putting card-owned behavior such as `Card::Closeable` under `app/models/card`, and exposes lifecycle operations through focused controllers such as `Cards::ClosuresController`. Once Campfire similarly uses model-owned namespaces such as `Message::Attachment`. These examples support selective ownership namespaces, not mechanical nesting of every child record.

**Sources**:

- [Fizzy models](https://github.com/basecamp/fizzy/tree/main/app/models)
- [Fizzy card model namespace](https://github.com/basecamp/fizzy/tree/main/app/models/card)
- [Card::Closeable](https://github.com/basecamp/fizzy/blob/main/app/models/card/closeable.rb)
- [Cards::ClosuresController](https://github.com/basecamp/fizzy/blob/main/app/controllers/cards/closures_controller.rb)
- [Once Campfire Message::Attachment](https://github.com/basecamp/once-campfire/blob/main/app/models/message/attachment.rb)

**Alternatives rejected**:

- `Financial::Plan::PlannedTransaction`: suggests the record cannot participate outside one plan and creates a rename without fixing behavior.
- Concerns for every operation: one reorder method does not justify a concern. Extract only if the plan later accumulates a cohesive ordering subsystem.

## 3. Keep planned and actual funding separate

**Decision**: Planned Funding is the sum of every funding source's expected amount. Actual Funding is the sum of recorded funding receipt entries. Financial account current balances are not part of either calculation.

**Rationale**: The restored Planned/Actual summary should compare intention with execution instead of blending them. Bank ledger balances can include unrelated or incompletely registered activity, so they do not represent either the plan's expected funding or its recorded receipts.

**Alternatives rejected**:

- Replace expected funding with receipts as they arrive: obscures the original plan and duplicates Actual Funding.
- Current account balances: may include unrelated entries or negative balances caused by incomplete registration.
- Every active asset account: includes money never selected for this plan.
- A new plan-account join table: existing funding destinations already express the selection; add a table only if users later need accounts with no funding source.

## 4. Keep planned and actual consumption separate

**Decision**: Planned Consumption includes every cash-consuming planned movement, including applied movements. Actual Consumption includes only actual expense entries produced by applied movements. Transfers between assets and liability charges remain visible but neutral in both balances.

**Rationale**: The Planned row preserves the complete intended plan while the Actual row reports what has happened. Each side counts its own records exactly once, so applying a movement does not erase its planned meaning or double-count one record in the same row.

**Alternatives rejected**:

- Pending-only Planned Consumption: turns the Planned row into a changing remainder and loses the original plan total.
- Add actual entries into Planned Consumption: mixes planned and actual facts.
- Deduct all movement kinds indiscriminately: treats transfers and other non-cash movements as spending.
- Keep `commits_plan_funds` as the deciding switch: plan membership already expresses that a liability payment belongs to this plan; requiring another checkbox would make Planned Consumption depend on hidden secondary state.

## 5. Keep one persisted custom sequence

**Decision**: Retain `planned_expenses.position` as the custom sequence and add one `custom_ordered` flag to the plan row. Due-date order is derived at read time and never persisted into positions.

**Rationale**: Positions already have a unique database index and new records already append. The flag is the smallest state needed to distinguish untouched insertion positions from an intentional custom order.

**Alternatives rejected**:

- Two position columns: due-date order is derived data.
- Persist the currently viewed sort: switching views does not change domain state.
- Infer manual ordering from position/date differences: insertion order can differ from due-date order before the user prioritizes anything.

## 6. Reorder through the plan aggregate

**Decision**: `Financial::Plan#reorder_planned_transactions!` validates the complete ID set and updates positions atomically under a lock. A singular nested HTTP order resource calls it.

**Rationale**: The invariant is plan-wide: positions must be unique, contiguous, and limited to that account's plan. Updating one row at a time through the controller can leave duplicates or partial order after failure.

**Alternatives rejected**:

- One request per dragged row: creates intermediate invalid states and extra requests.
- A generic sortable service: only plan movements need this behavior today.
- Browser-only ordering: fails persistence and cannot protect financial identity.

## 7. Keep sort switching on plan show

**Decision**: `GET /finance/plans/:id?order=custom|due_date` chooses presentation order and recalculates rows in that order. Invalid or absent values use the plan's default.

**Rationale**: This is a read concern, not a resource state transition. A query parameter keeps links shareable and works with Turbo without a separate controller.

**Alternatives rejected**:

- Persist every sort toggle: adds writes for temporary viewing preference.
- Separate projection endpoint/Turbo Frame: the section has no independent authorization or loading need yet.

## 8. Preserve planned and actual dates

**Decision**: Applying defaults the actual entry date from `due_date`, then `planned_for`, then today, while allowing user override. Timing is derived by comparing the linked entry date with the untouched due date.

**Rationale**: A due date is a plan fact; an entry date is an actual fact. The existing relation already stores both and the application flow already accepts an override.

**Alternatives rejected**:

- Rewrite due date on payment: destroys the original expectation.
- Use `applied_on` as the only actual date: the financial entry is the ledger source of truth.
- Add a timing-status column: early/on-time/late is derived and would become stale.

## 9. Restore the existing summary and use compact native controls

**Decision**: Restore the two-row "Projection and plan execution" summary with Funding, Consumption, and Plan balance columns. Reuse project buttons, badges, inputs, and selects. Keep native drag-and-drop and use icon-sized up/down buttons with inline SVGs and movement-specific accessible labels.

**Rationale**: The previous summary is familiar and already matches the planned-versus-actual distinction. The canonical button component already has an icon size, the application already uses inline SVG, no sortable dependency is installed, and accessibility cannot depend on dragging.

**Alternatives rejected**:

- New metric-card summary: consumes more attention and replaces familiar labels without adding behavior.
- Add SortableJS: unnecessary for a small ordered list.
- Drag-only UI: excludes keyboard and assistive-technology users.
- A new shared component before a second use exists: speculative abstraction.

## 10. Keep overview calculations separate

**Decision**: `Financial::Plans::Overview` owns totals for the filtered plans collection; `Financial::Plan::Projection` and `Financial::Plan::Actuals` use only one plan's records.

**Rationale**: The existing preceding-plan carryover makes a plan page look date-bounded and mixes portfolio chronology into one execution decision. A collection calculation is meaningful on the overview and should be labeled there.

**Alternatives rejected**:

- Keep carryover inside each plan projection: conflicts with the plan's unrestricted membership and obscures current cash.
- Put sums directly in the controller/view: financial arithmetic belongs at a testable domain boundary.

## 11. Keep route corrections on the planned record

**Decision**: Add source and destination selectors to the existing planned-movement edit flow. A correction changes only the planned movement, even after application; the linked actual entry remains untouched. Existing amount and due-date protections remain in place.

**Rationale**: The plan route is an expectation and the entry route is a ledger fact. Correcting the former must not silently rewrite the latter. The existing selection writers and validations already encode account-type routing, so no new route model or endpoint is needed.

**Alternatives rejected**:

- A separate route resource: one existing edit flow already owns planned expectation corrections.
- Editing the actual entry at the same time: violates the planned/actual boundary and can rewrite history unexpectedly.
- A new polymorphic route model: duplicates existing foreign keys and selection behavior.

## 12. Keep funding destinations on their source items

**Decision**: Show the selected destination account as a badge on each existing funding-source item and remove the separate funding-account summary block.

**Rationale**: A funding source has a destination but no independent origin account. Showing that destination beside the source preserves context with the smallest UI change and avoids repeating the same data in a new section.

**Alternatives rejected**:

- Add an origin-account field: the domain has no requirement for one.
- Keep a separate destination summary: duplicates information and consumes page space.
- Show no destination: forces the user to open the edit form to verify where funding goes.
