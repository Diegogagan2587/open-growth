# Feature Specification: Quincena Plan Execution

**Feature Branch**: `003-quincena-plan-execution`

**Created**: 2026-09-16

**Status**: Draft

**Input**: User description: "Make a financial plan useful for executing the payments of the current quincena by showing the money available, the money still required, payments in due-date order, payment status, and the account route for every planned movement. Keep global calculations on the plans overview and plan-specific calculations on the individual plan."

## User Scenarios & Testing *(mandatory)*

### User Story 1 - Know Whether the Quincena Is Funded (Priority: P1)

As a user preparing payments for a specific quincena, I can immediately compare the money available from the plan's selected funding accounts with the amount still required for that plan, so I know whether I can complete every pending payment or must cover a shortfall.

**Why this priority**: The plan fails its primary purpose if the user cannot answer how much money is available and how much is still needed for the period being executed.

**Independent Test**: Open a plan containing selected funding accounts and dated planned payments, then verify that the available amount, pending required amount, expected remainder, and shortfall are visible and reconcile with the underlying amounts.

**Acceptance Scenarios**:

1. **Given** a plan whose available funding exceeds its pending payments, **When** the user opens the plan, **Then** the plan shows the available amount, required amount, and non-negative expected remainder.
2. **Given** a plan whose pending payments exceed its available funding, **When** the user opens the plan, **Then** the plan shows the exact shortfall without presenting the plan as fully funded.
3. **Given** a plan containing an already-paid movement, **When** current account balances already reflect that payment, **Then** the plan does not deduct the payment a second time from the money available.
4. **Given** a planned payment without a known amount, **When** the user opens the plan, **Then** the payment is marked incomplete and the plan states that its required-total calculation is incomplete rather than treating the amount as zero.

---

### User Story 2 - Execute Payments in Due-Date Order (Priority: P1)

As a user carrying out the plan, I can see all payments ordered by payment due date with their amount and status, so I can pay the right obligation at the right time and track what remains.

**Why this priority**: A correct total is not operationally useful unless the user can identify the individual obligations and the order in which they must be handled.

**Independent Test**: Open a plan with paid and pending payments across multiple dates and verify that every payment is visible in chronological order with its due date, amount or incomplete marker, and status.

**Acceptance Scenarios**:

1. **Given** payments due on different dates, **When** the user reviews the plan, **Then** they appear from earliest due date to latest due date.
2. **Given** multiple payments due on the same date, **When** the user reviews the plan repeatedly, **Then** their relative order remains stable.
3. **Given** paid and pending payments in the same period, **When** the user reviews the plan, **Then** paid payments remain visible and are clearly distinguishable from pending payments.
4. **Given** a payment representing a minimum amount rather than full settlement, **When** the user reviews it, **Then** that meaning is visible alongside the amount.
5. **Given** a planned payment has an incorrect or missing due date, **When** the user assigns or corrects its planned due date, **Then** the payment moves to the corresponding chronological position without changing any actual payment date.
6. **Given** the plan contains a refinancing-related movement, **When** the user reviews the execution order, **Then** its purpose, amount, date, status, and account route are visible alongside other planned movements.

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

As a user managing several financial plans, I can use the plans overview for global information and an individual plan for that plan's execution calculations, so unrelated financial information does not obscure the current quincena.

**Why this priority**: Global context remains useful, but mixing it into one plan prevents the user from understanding the plan's immediate reality.

**Independent Test**: Compare the plans overview with one plan and verify that portfolio-wide information appears in the overview while funding, obligations, routing, and projections for the selected plan appear in that plan.

**Acceptance Scenarios**:

1. **Given** multiple plans exist, **When** the user opens the plans overview, **Then** the user sees global information without mistaking it for one plan's available or required amount.
2. **Given** the user opens one plan, **When** its calculations are shown, **Then** they include only that plan's funding and movements.

### Edge Cases

- A plan has no selected funding accounts; available funding is shown as zero and the plan identifies that no funding source is configured.
- A plan has no planned payments; required funding and shortfall are zero and the empty state explains that no payments are scheduled.
- A payment has no amount; it remains visible, is excluded from numeric totals, and makes those totals explicitly incomplete.
- A payment has no due date; it remains visible after dated payments and is marked as unscheduled.
- A source or destination account is missing or no longer available; the movement remains visible and its route is marked incomplete.
- Two or more payments share a due date; their ordering remains stable between views.
- A payment is made outside its planned due date; the planned due date and actual payment state remain distinct.
- Current account balances already include a completed payment; calculations do not count the completed payment twice.
- Money is available across multiple selected accounts; the total equals the sum of the displayed account-level available amounts.
- A plan includes obligations outside its planning period; they do not affect the plan-specific totals for the selected period.

## Requirements *(mandatory)*

### Functional Requirements

- **FR-001**: The system MUST show the planning period represented by an individual financial plan.
- **FR-002**: The system MUST show the money available to the plan from its selected funding accounts.
- **FR-003**: The system MUST show the account-level amounts that compose the plan's total available funding.
- **FR-004**: The system MUST show the total amount still required for pending planned payments within the plan's planning period.
- **FR-005**: The system MUST show the expected remainder when funding covers pending payments and the exact shortfall when it does not.
- **FR-006**: The system MUST state when available, required, remainder, or shortfall calculations are incomplete because required financial information is missing.
- **FR-007**: The system MUST display every planned payment belonging to the plan, including paid, pending, incomplete, and unscheduled payments.
- **FR-008**: The system MUST order dated planned payments from earliest due date to latest due date and place unscheduled payments after dated payments.
- **FR-009**: The system MUST use a stable order for payments sharing the same due date.
- **FR-010**: Each planned payment MUST show its purpose or description, amount or missing-amount state, due date or unscheduled state, and payment status.
- **FR-011**: The system MUST allow a planned payment to communicate that its amount represents a minimum payment or another limited payment obligation rather than a full settlement.
- **FR-012**: Each planned movement MUST show its source account, destination account, and direction of movement.
- **FR-013**: The system MUST identify missing source, destination, amount, or due-date information without hiding the affected movement.
- **FR-014**: The system MUST preserve the distinction between a planned movement and the actual financial movement that fulfills it.
- **FR-015**: Marking or recognizing a payment as paid MUST NOT silently replace, rewrite, or erase its original planned amount and due date.
- **FR-016**: Plan calculations MUST avoid double-counting paid movements when the balance basis already reflects their actual financial effect.
- **FR-017**: Individual-plan totals MUST include only funding and movements belonging to that plan and its planning period.
- **FR-018**: Portfolio-wide calculations MUST remain distinguishable from calculations for an individual plan.
- **FR-019**: The plans overview MUST present portfolio-wide information, while an individual plan MUST present its own funding, payment schedule, routing, and execution calculations.
- **FR-020**: All displayed monetary totals MUST reconcile exactly with the monetary items shown as contributing to those totals.
- **FR-021**: A user MUST be able to determine the running amount expected to remain after each pending payment in the displayed execution order.
- **FR-022**: The system MUST clearly identify the balance basis used for the plan's execution calculation so paid movements are interpreted consistently.
- **FR-023**: A user MUST be able to assign or correct a planned movement's due date, and changing that planned date MUST NOT change an actual movement's date.
- **FR-024**: The plan MUST include refinancing-related movements in the same dated execution view when they belong to the plan's planning period.

### Key Entities

- **Financial Plan**: The user's financial intention for a defined planning period, containing selected funding and planned movements and owning the plan-specific execution view.
- **Planning Period**: The date range whose funding and obligations define the plan's immediate execution scope; the user may refer to this period as a quincena.
- **Funding**: Money made available to the plan from one or more selected financial accounts, including the account-level amounts composing the available total.
- **Planned Movement**: A proposed payment or refinancing-related movement of money with a purpose, amount, due date, status, source account, destination account, and optional payment meaning such as minimum payment.
- **Actual Movement**: The real financial movement that may fulfill a planned movement while retaining distinct actual and planned dates and amounts.
- **Plan Projection**: The calculated sequence of required payments, running remaining funds, expected final remainder, or shortfall for one plan and planning period.
- **Financial Account**: A source or destination of money whose identity and role must remain visible when the user executes a planned movement.

## Success Criteria *(mandatory)*

### Measurable Outcomes

- **SC-001**: A user can identify the plan's available money, pending required money, and expected remainder or shortfall within 30 seconds of opening the plan.
- **SC-002**: In acceptance testing, 100% of dated payments appear in ascending due-date order and all undated payments appear afterward as unscheduled.
- **SC-003**: In acceptance testing, 100% of displayed payments show an amount or explicit missing-amount state, a date or unscheduled state, a status, and their account route or explicit missing-route state.
- **SC-004**: For every complete plan tested, available funding equals the sum of displayed funding amounts and required funding equals the sum of displayed contributing pending payments, with no rounding discrepancy.
- **SC-005**: For every underfunded plan tested, the displayed shortfall exactly equals pending required money minus available money.
- **SC-006**: For every overfunded or exactly funded plan tested, the displayed expected remainder exactly equals available money minus pending required money.
- **SC-007**: Paid movements whose effects are already present in current balances are never deducted a second time in tested plan projections.
- **SC-008**: A user can identify the source and destination accounts for a complete planned movement without navigating away from the plan.
- **SC-009**: Missing amounts, dates, or routing information never cause a movement to disappear and are explicitly identifiable in 100% of tested incomplete-plan cases.
- **SC-010**: Portfolio-wide figures and individual-plan figures are labeled and scoped clearly enough that acceptance-test users do not confuse one for the other.

## Assumptions

- A plan has a defined planning period. The colloquial term "quincena" refers to that configured period rather than imposing a new universal calendar rule.
- Available funding is derived only from accounts intentionally selected for the plan; unrelated account balances do not contribute to plan-specific totals.
- The balance basis may use current balances or an explicitly established plan basis, but it must be visible and applied consistently so actual payments are not counted twice.
- A payment marked paid remains visible because execution history is necessary to understand the plan.
- A minimum-payment label describes the meaning of a planned amount; calculating a creditor's minimum payment is outside this feature.
- Account balances, planned movements, actual movements, and account identities already exist or can be obtained from the application's established financial records.
- This feature improves plan understanding and execution; it does not initiate transfers with external financial institutions.
- Representing refinancing-related movements during plan execution is in scope; automatically recommending or optimizing refinancing decisions is outside this feature.
- The living specification owns financial-plan execution behavior. Future corrections or extensions to that same user outcome should update this specification rather than create another feature specification.
