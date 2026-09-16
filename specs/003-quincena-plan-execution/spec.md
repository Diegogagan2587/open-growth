# Feature Specification: Financial Plan Execution

**Feature Branch**: `003-quincena-plan-execution`

**Created**: 2026-09-16

**Status**: Draft

**Input**: User description: "Make a financial plan useful for executing whatever group of payments the user chooses to represent. Preserve the existing planned-for reference date without using it to limit plan contents. Show available money, money still required, user-prioritized payment order, payment status, and the account route for every planned movement. Keep global calculations on the plans overview and plan-specific calculations on the individual plan."

## Clarifications

### Session 2026-09-16

- Q: What time scope does a financial plan represent? → A: Any grouping the user wants; preserve the existing `planned_for` reference date for display and ordering plans, but never use it as a time boundary or to limit plan contents.
- Q: When manually reordered, should custom priority become the execution order even when it differs from due-date order? → A: Yes. Due-date order is the default, but the persisted manual order becomes authoritative while due dates remain visible.
- Q: Should manual reordering apply only to pending payments or also to already-paid payments? → A: Reordering applies to all planned movements, including applied ones, but never changes or reorders the actual transactions generated from them.
- Q: After custom ordering exists, where should a newly added planned movement appear? → A: Append it to the end of the custom order, while allowing quick switching between custom and due-date order.
- Q: When switching order, should the running-balance projection recalculate or should only the list display change? → A: Recalculate for the selected order and show the resulting balance beside every planned movement.
- Q: When applying a planned movement on a different date, should its planned due date remain unchanged while the generated actual transaction uses the selected payment date? → A: Yes. Preserve the planned due date, preselect it as the actual payment date, and allow the user to choose an earlier or later actual date.
- Q: After a planned movement is applied, what timing information should its plan row show? → A: Show the actual payment date and an Early, On time, or Late badge calculated against the preserved due date.
- Q: How should a plan calculate its opening available funding? → A: Sum every funding source's expected amount, replacing an individual source's expected amount with its actual received amount when a receipt transaction exists; do not use financial account current balances.

## User Scenarios & Testing *(mandatory)*

### User Story 1 - Know Whether the Plan Is Funded (Priority: P1)

As a user preparing a chosen group of payments, I can immediately compare the money available from the plan's funding sources with the amount still required for that plan, so I know whether I can complete every pending payment or must cover a shortfall.

**Why this priority**: The plan fails its primary purpose if the user cannot answer how much money is available and how much is still needed for the period being executed.

**Independent Test**: Open a plan containing funding sources and dated planned payments, then verify that the available amount, pending required amount, expected remainder, and shortfall are visible and reconcile with the underlying amounts.

**Acceptance Scenarios**:

1. **Given** a plan whose available funding exceeds its pending payments, **When** the user opens the plan, **Then** the plan shows the available amount, required amount, and non-negative expected remainder.
2. **Given** a plan whose pending payments exceed its available funding, **When** the user opens the plan, **Then** the plan shows the exact shortfall without presenting the plan as fully funded.
3. **Given** a plan containing an already-paid movement, **When** current account balances already reflect that payment, **Then** the plan does not deduct the payment a second time from the money available.
4. **Given** a planned payment without a known amount, **When** the user opens the plan, **Then** the payment is marked incomplete and the plan states that its required-total calculation is incomplete rather than treating the amount as zero.

---

### User Story 2 - Prioritize and Execute Payments (Priority: P1)

As a user carrying out the plan, I can see all payments in execution order and manually reprioritize them while retaining their due dates, amounts, and statuses, so the plan reflects what I have decided to pay first.

**Why this priority**: A correct total is not operationally useful unless the user can identify the individual obligations and the order in which they must be handled.

**Independent Test**: Open a plan with paid and pending payments across multiple dates, reorder payments across due dates, reopen the plan, and verify that the chosen execution order persists while every due date, amount or incomplete marker, and status remains visible.

**Acceptance Scenarios**:

1. **Given** payments have not been manually reordered, **When** the user reviews the plan, **Then** they appear from earliest due date to latest due date, with unscheduled payments afterward.
2. **Given** the user manually reorders payments, **When** the plan is reopened, **Then** the chosen order persists and becomes the execution order even when it differs from due-date order.
3. **Given** paid and pending payments in the same period, **When** the user reviews the plan, **Then** paid payments remain visible and are clearly distinguishable from pending payments.
4. **Given** a payment representing a minimum amount rather than full settlement, **When** the user reviews it, **Then** that meaning is visible alongside the amount.
5. **Given** a planned payment has an incorrect or missing due date, **When** the user assigns or corrects its planned due date, **Then** the payment moves to the corresponding chronological position without changing any actual payment date.
6. **Given** the plan contains a refinancing-related movement, **When** the user reviews the execution order, **Then** its purpose, amount, date, status, and account route are visible alongside other planned movements.
7. **Given** the user changes the execution order, **When** running remaining funds are recalculated, **Then** each running amount follows the new order without changing total required funding.
8. **Given** a planned movement has already been applied to an actual transaction, **When** the user reorders that planned movement, **Then** the planned movement changes position while the actual transaction and its selected payment date remain unchanged.
9. **Given** the plan has a custom order, **When** a new planned movement is added, **Then** it appears at the end of the custom order without changing existing priorities.
10. **Given** the plan has a custom order, **When** the user switches to due-date order and back, **Then** the list changes quickly between views and the saved custom order is preserved.
11. **Given** the user selects custom or due-date order, **When** the planned movements are displayed, **Then** the balance beside each movement shows the money remaining at that point in the selected order.
12. **Given** a planned movement due on one date, **When** the user applies it, **Then** the actual payment date is preselected from the due date and the user can replace it with an earlier or later date without changing the planned due date.
13. **Given** an applied planned movement has both a due date and actual payment date, **When** the user reviews the plan, **Then** the row shows the actual date and identifies the payment as Early, On time, or Late.

---

### User Story 3 - Verify the Account Route (Priority: P2)

As a user executing each payment, I can see where the money must come from and where it must go, so the real transfer I perform matches the accounts selected during planning.

**Why this priority**: Hidden routing forces the user to guess and can cause a financially correct amount to be transferred through the wrong accounts.

**Independent Test**: Open a plan containing movements between different account pairs and verify that each movement identifies its source and destination accounts without requiring the user to inspect another screen.

**Acceptance Scenarios**:

1. **Given** a planned movement with a source and destination account, **When** the user reviews the movement, **Then** both accounts and the direction of movement are visible.
2. **Given** a planned movement with missing routing information, **When** the user reviews the plan, **Then** the movement is marked incomplete and the missing side of the route is identified.
3. **Given** several funding accounts are selected for a plan, **When** the user reviews available funding, **Then** the contribution or available amount associated with each selected account is visible.

---

### User Story 4 - Separate Portfolio and Plan Decisions (Priority: P3)

As a user managing several financial plans, I can use the plans overview for global information and an individual plan for that plan's execution calculations, so unrelated financial information does not obscure the plan I am currently executing.

**Why this priority**: Global context remains useful, but mixing it into one plan prevents the user from understanding the plan's immediate reality.

**Independent Test**: Compare the plans overview with one plan and verify that portfolio-wide information appears in the overview while funding, obligations, routing, and projections for the selected plan appear in that plan.

**Acceptance Scenarios**:

1. **Given** multiple plans exist, **When** the user opens the plans overview, **Then** the user sees global information without mistaking it for one plan's available or required amount.
2. **Given** the user opens one plan, **When** its calculations are shown, **Then** they include only that plan's funding and movements.
3. **Given** plans have different planned-for reference dates, **When** the user opens the plans overview, **Then** those dates are visible and can determine the plans' display order without restricting plan contents.

### Edge Cases

- A plan has no funding sources; available funding is shown as zero and the plan identifies that no funding source is configured.
- A plan has no planned payments; required funding and shortfall are zero and the empty state explains that no payments are scheduled.
- A payment has no amount; it remains visible, is excluded from numeric totals, and makes those totals explicitly incomplete.
- A payment has no due date; it remains visible after dated payments and is marked as unscheduled.
- A source or destination account is missing or no longer available; the movement remains visible and its route is marked incomplete.
- Two or more payments share a due date; their default ordering remains stable until the user manually changes it.
- A payment is made before or after its planned due date; the planned due date remains unchanged and the actual transaction records the user-selected payment date.
- An applied movement has no due date; its actual payment date remains visible, but no early/on-time/late comparison is claimed.
- Current account balances already include a completed payment; calculations do not count the completed payment twice.
- Money is available across multiple funding sources; the total equals the sum of each source's effective amount, using its actual receipt amount when received and expected amount otherwise.
- A selected funding account has a negative or incomplete current ledger balance; that balance does not change the plan's funding-source total.
- A plan contains movements with dates far from its planned-for reference date; they remain part of the plan and its totals because plan membership is not date-bound.
- A manually prioritized payment has a later due date than another payment; the manual execution order is preserved while both due dates remain visible.
- An applied planned movement is reordered; its linked actual transaction retains its selected actual payment date, amount, identity, and financial effect.
- A new movement is added after custom ordering exists; it is appended without reshuffling existing planned movements.

## Requirements *(mandatory)*

### Functional Requirements

- **FR-001**: The system MUST preserve and show the plan's existing `planned_for` reference date.
- **FR-002**: The system MUST show the money available to the plan as the sum of every funding source's effective amount, using its actual received amount when available and its expected amount otherwise.
- **FR-003**: The system MUST show the funding-source contributions that compose the plan's total available funding.
- **FR-004**: The system MUST show the total amount still required for pending planned payments belonging to the plan.
- **FR-005**: The system MUST show the expected remainder when funding covers pending payments and the exact shortfall when it does not.
- **FR-006**: The system MUST state when available, required, remainder, or shortfall calculations are incomplete because required financial information is missing.
- **FR-007**: The system MUST display every planned payment belonging to the plan, including paid, pending, incomplete, and unscheduled payments.
- **FR-008**: Before a user manually prioritizes payments, the system MUST order dated planned payments from earliest due date to latest due date and place unscheduled payments afterward.
- **FR-009**: A user MUST be able to manually reorder planned payments across different due dates, and that order MUST persist as the plan's execution order.
- **FR-010**: Each planned payment MUST show its purpose or description, amount or missing-amount state, due date or unscheduled state, and payment status.
- **FR-011**: The system MUST allow a planned payment to communicate that its amount represents a minimum payment or another limited payment obligation rather than a full settlement.
- **FR-012**: Each planned movement MUST show its source account, destination account, and direction of movement.
- **FR-013**: The system MUST identify missing source, destination, amount, or due-date information without hiding the affected movement.
- **FR-014**: The system MUST preserve the distinction between a planned movement and the actual financial movement that fulfills it.
- **FR-015**: Marking or recognizing a payment as paid MUST NOT silently replace, rewrite, or erase its original planned amount and due date.
- **FR-029**: Applied planned movements MUST remain independently reorderable as planned records without changing their linked actual transactions.
- **FR-016**: Plan calculations MUST deduct each plan movement that consumes cash, including applied movements, from the funding-source opening amount; transfers MUST remain neutral and movements that do not consume cash MUST not be deducted.
- **FR-017**: Individual-plan totals MUST include only funding and movements belonging to that plan, regardless of their dates.
- **FR-018**: Portfolio-wide calculations MUST remain distinguishable from calculations for an individual plan.
- **FR-019**: The plans overview MUST present portfolio-wide information, while an individual plan MUST present its own funding, payment schedule, routing, and execution calculations.
- **FR-020**: All displayed monetary totals MUST reconcile exactly with the monetary items shown as contributing to those totals.
- **FR-021**: A user MUST be able to determine the running amount expected to remain after each pending payment in the displayed execution order.
- **FR-022**: The system MUST clearly identify that plan execution starts from funding-source amounts rather than financial account current balances.
- **FR-023**: A user MUST be able to assign or correct a planned movement's due date, and changing that planned date MUST NOT change an actual movement's date.
- **FR-024**: The plan MUST include refinancing-related movements in the same execution view when they belong to the plan.
- **FR-025**: Manual reordering MUST NOT change payment amounts, due dates, statuses, account routes, or total required funding.
- **FR-026**: Running remaining funds MUST follow whichever order the user is currently viewing.
- **FR-027**: The system MUST use `planned_for` as reference information and to order plans in the plans view, not as a boundary that includes or excludes funding or movements.
- **FR-028**: Manual reordering MUST change only the display and execution priority of planned movements; it MUST NOT reorder or mutate actual transactions.
- **FR-030**: Once a custom order exists, each newly added planned movement MUST be appended to its end without changing the relative order of existing movements.
- **FR-031**: A user MUST be able to switch quickly between persisted custom order and due-date order.
- **FR-032**: Viewing movements in due-date order MUST NOT erase or rewrite the persisted custom order.
- **FR-033**: The system MUST recalculate and show the running balance beside every planned movement whenever the user switches between custom and due-date order.
- **FR-034**: When applying a planned movement, the system MUST preselect its due date as the actual payment date and allow the user to choose an earlier or later actual date.
- **FR-035**: Applying or reordering a planned movement MUST preserve its planned due date separately from the actual transaction's selected payment date.
- **FR-036**: Each applied planned movement MUST show its actual payment date in the plan's planned-movements view.
- **FR-037**: When both dates exist, the system MUST label an applied planned movement Early when its actual payment date precedes its due date, On time when the dates match, and Late when its actual payment date follows its due date.
- **FR-038**: When an applied planned movement has no due date, the system MUST show its actual payment date without assigning an early/on-time/late status.

### Key Entities

- **Financial Plan**: The user's chosen grouping of selected funding and ordered planned movements, owning the plan-specific execution view without requiring a date-bounded scope.
- **Planned-For Reference**: The existing reference date that helps the user describe and order plans; it does not determine which funding or movements belong to a plan.
- **Funding**: Money made available to the plan from one or more selected financial accounts, including the account-level amounts composing the available total.
- **Planned Movement**: A proposed payment or refinancing-related movement of money with its own display priority, purpose, amount, due date, status, source account, destination account, and optional payment meaning such as minimum payment; it remains independently orderable after application.
- **Actual Movement**: The real financial movement that may fulfill a planned movement while retaining distinct actual and planned dates and amounts.
- **Plan Projection**: The calculated execution sequence, running remaining funds, expected final remainder, or shortfall for one plan.
- **Financial Account**: A source or destination of money whose identity and role must remain visible when the user executes a planned movement.

## Success Criteria *(mandatory)*

### Measurable Outcomes

- **SC-001**: A user can identify the plan's available money, pending required money, and expected remainder or shortfall within 30 seconds of opening the plan.
- **SC-002**: In acceptance testing, 100% of plans without manual prioritization default to ascending due-date order with unscheduled payments afterward, and 100% of manually reordered plans preserve the chosen execution order after reopening.
- **SC-003**: In acceptance testing, 100% of displayed payments show an amount or explicit missing-amount state, a date or unscheduled state, a status, and their account route or explicit missing-route state.
- **SC-004**: For every complete plan tested, available funding equals the sum of displayed funding-source effective amounts and required funding equals the sum of displayed contributing pending payments, with no rounding discrepancy.
- **SC-005**: For every underfunded plan tested, the displayed shortfall exactly equals pending required money minus available money.
- **SC-006**: For every overfunded or exactly funded plan tested, the displayed expected remainder exactly equals available money minus pending required money.
- **SC-007**: Every tested applied cash-consuming movement is deducted once from the funding-source opening amount, while transfers and other non-cash-consuming movements are not deducted.
- **SC-008**: A user can identify the source and destination accounts for a complete planned movement without navigating away from the plan.
- **SC-009**: Missing amounts, dates, or routing information never cause a movement to disappear and are explicitly identifiable in 100% of tested incomplete-plan cases.
- **SC-010**: Portfolio-wide figures and individual-plan figures are labeled and scoped clearly enough that acceptance-test users do not confuse one for the other.
- **SC-011**: Reordering payments changes 0 payment amounts, due dates, statuses, account routes, or required-total values, while 100% of running-balance rows follow the new order.
- **SC-012**: In acceptance testing, movements belonging to a plan remain included regardless of whether their dates are before, on, or after the plan's planned-for reference date.
- **SC-013**: Reordering an applied planned movement changes 0 fields and 0 ordering attributes on its linked actual transaction.
- **SC-014**: After adding a movement to a custom-ordered plan, 100% of previously ordered movements retain their relative positions and the new movement appears last.
- **SC-015**: A user can switch between custom and due-date order in one interaction, and repeated switching preserves the custom order exactly.
- **SC-016**: In both custom and due-date views, 100% of planned movements show the mathematically correct balance remaining at that point in the selected order.
- **SC-017**: In acceptance testing, payments recorded before, on, and after their due dates preserve the planned due date and store the selected actual payment date exactly.
- **SC-018**: In acceptance testing, 100% of applied movements with both dates show the actual payment date and the correct Early, On time, or Late label.

## Assumptions

- The existing `planned_for` property is a reference date, not a planning-period boundary, recurrence rule, or restriction on plan membership.
- Available funding is derived from the plan's funding sources; financial account balances do not contribute to plan-specific totals.
- The funding-source basis is visible and applied consistently: each received source uses its actual amount, each unreconciled source uses its expected amount, and each cash-consuming plan movement is deducted once.
- A payment marked paid remains visible because execution history is necessary to understand the plan.
- A minimum-payment label describes the meaning of a planned amount; calculating a creditor's minimum payment is outside this feature.
- Account balances, planned movements, actual movements, and account identities already exist or can be obtained from the application's established financial records.
- This feature improves plan understanding and execution; it does not initiate transfers with external financial institutions.
- Representing refinancing-related movements during plan execution is in scope; automatically recommending or optimizing refinancing decisions is outside this feature.
- The living specification owns financial-plan execution behavior. Future corrections or extensions to that same user outcome should update this specification rather than create another feature specification.
