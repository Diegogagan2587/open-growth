---

description: "Dependency-ordered tasks for financial plan execution"
---

# Tasks: Financial Plan Execution

**Input**: Design documents from `/specs/003-quincena-plan-execution/`

**Prerequisites**: `plan.md`, `spec.md`, `research.md`, `data-model.md`, `contracts/http.md`, `quickstart.md`

**Tests**: Required by the project constitution and implementation plan. Write each focused test first, confirm the expected failure, then implement the smallest passing change.

**Organization**: Tasks are grouped by user story so each increment can be implemented and verified at its own boundary.

## Format: `[ID] [P?] [Story] Description`

- **[P]**: Can run in parallel because it changes different files and does not depend on an incomplete task.
- **[Story]**: Maps the task to a user story in `spec.md`.
- Every task names its exact repository path.

## Phase 1: Setup and Baseline

**Purpose**: Confirm the existing financial-plan behavior before moving or changing it.

- [X] T001 Run the existing financial-plan tests in `test/models/financial/plan/projection_test.rb`, `test/models/financial/plan/actuals_test.rb`, `test/models/financial/plan_test.rb`, `test/models/financial/planned_transaction_test.rb`, `test/controllers/financial/plans_controller_test.rb`, and `test/services/financial/planned_transactions/apply_service_test.rb`

---

## Phase 2: Foundational Namespaces

**Purpose**: Establish the plan-owned model boundaries used by every story without changing behavior.

**⚠️ CRITICAL**: Complete this phase before user-story implementation.

- [X] T002 Move `Financial::PlanProjection` to `Financial::Plan::Projection` in `app/models/financial/plan/projection.rb`, move its tests to `test/models/financial/plan/projection_test.rb`, and update references in `app/controllers/financial/plans_controller.rb`
- [X] T003 Move `Financial::PlanActuals` to `Financial::Plan::Actuals` in `app/models/financial/plan/actuals.rb`, move its tests to `test/models/financial/plan/actuals_test.rb`, and update references in `app/controllers/financial/plans_controller.rb`

**Checkpoint**: Existing behavior passes under `Financial::Plan::*` with no compatibility duplicate classes.

---

## Phase 3: User Story 1 - Know Whether the Plan Is Funded (Priority: P1) 🎯 MVP

**Goal**: Restore the familiar Planned/Actual metric cards and make Reserve funds drive planned consumption consistently.

**Independent Test**: Open a plan with expected funding, recorded receipts, expenses, reserved and unreserved neutral movements, and applied movements; verify Planned and Actual Funding, Consumption, and Plan balance reconcile independently and can be negative.

### Tests for User Story 1

- [X] T004 [P] [US1] Add failing Planned Funding, Reserve funds, applied-movement, negative-balance, and visible-order running-balance tests in `test/models/financial/plan/projection_test.rb`
- [X] T005 [P] [US1] Add failing plan-balance classification, editable-lifecycle, applied-record, and linked-actual immutability tests in `test/models/planned_expense_test.rb` and `test/models/financial/planned_transaction_test.rb`
- [X] T006 [P] [US1] Add failing Actual Funding receipt and Actual Consumption expense-entry tests in `test/models/financial/plan/actuals_test.rb`
- [X] T007 [P] [US1] Add failing metric-card summary, Reserve funds control, and Funds reserved badge assertions in `test/controllers/financial/plans_controller_test.rb`

### Implementation for User Story 1

- [X] T008 [US1] Define one shared plan-balance predicate for expenses and reserved neutral movements in `app/models/planned_expense.rb` and `app/models/financial/planned_transaction.rb`
- [X] T009 [US1] Calculate expected Planned Funding, predicate-based Planned Consumption, negative Plan balance, and ordered running balances in `app/models/financial/plan/projection.rb`
- [X] T010 [US1] Calculate Actual Funding from funding receipts and Actual Consumption from actual expense entries in `app/models/financial/plan/actuals.rb`
- [X] T011 [US1] Permit Reserve funds updates for pending and applied movements on editable plans without mutating linked actual entries in `app/controllers/financial/planned_transactions_controller.rb` and `app/models/financial/planned_transaction.rb`
- [X] T012 [US1] Restore the existing Funding, Consumption, and Plan balance card grid with Planned above Actual in `app/views/financial/plans/_metrics.html.erb`
- [X] T013 [US1] Restore the Reserve funds edit control and render the Funds reserved badge in `app/views/financial/plans/_planned_transactions.html.erb`
- [X] T014 [US1] Run the focused User Story 1 tests from `test/models/financial/plan/projection_test.rb`, `test/models/financial/plan/actuals_test.rb`, `test/models/planned_expense_test.rb`, `test/models/financial/planned_transaction_test.rb`, and `test/controllers/financial/plans_controller_test.rb`

**Checkpoint**: Planned and Actual values remain distinct, reconcile to visible contributors, and use the same Reserve funds rule everywhere.

---

## Phase 4: User Story 2 - Prioritize and Execute Payments (Priority: P1)

**Goal**: Persist custom order, retain due-date order as a quick alternate view, and provide compact accessible controls.

**Independent Test**: Reorder pending and applied movements, reload, switch between custom and due-date order, and apply a movement on another date; verify planned order changes while actual data remains unchanged.

### Tests for User Story 2

- [X] T015 [P] [US2] Add atomic reorder, complete-ID validation, applied-movement, rollback, and append-after-custom-order tests in `test/models/financial/plan_test.rb` and `test/controllers/financial/plans/planned_transaction_orders_controller_test.rb`
- [X] T016 [P] [US2] Add due-date/custom ordering, stable tie, unscheduled-last, date override, timing, and actual immutability tests in `test/models/financial/planned_transaction_test.rb`, `test/models/financial/plan/projection_test.rb`, and `test/services/financial/planned_transactions/apply_service_test.rb`
- [X] T017 [P] [US2] Add failing compact icon and movement-specific accessible-label assertions in `test/components/ui/button_component_test.rb` and `test/controllers/financial/plans_controller_test.rb`

### Implementation for User Story 2

- [X] T018 [US2] Add the reversible custom-order state migration and schema update in `db/migrate/*_add_custom_ordered_to_income_events.rb` and `db/schema.rb`
- [X] T019 [US2] Implement default order selection and transactional full-list reordering in `app/models/financial/plan.rb`
- [X] T020 [US2] Add the singular nested order route and account-scoped update action in `config/routes.rb` and `app/controllers/financial/plans/planned_transaction_orders_controller.rb`
- [X] T021 [US2] Add custom/due-date switching, full-order submission, drag enhancement, actual dates, timing badges, and selected-order balances in `app/views/financial/plans/_planned_transactions.html.erb` and `app/javascript/controllers/planned_transaction_order_controller.js`
- [X] T022 [US2] Preserve due dates and default actual dates while accepting earlier or later user-selected dates in `app/components/financial/installment_payment_form_component.rb` and `app/services/financial/planned_transactions/apply_service.rb`
- [X] T023 [US2] Support icon-only button content with an explicit accessible label in `app/components/ui/button_component.rb` and `app/components/ui/button_component.html.erb`
- [X] T024 [US2] Replace full-text move controls with compact up/down SVG icon buttons in `app/views/financial/plans/_planned_transactions.html.erb`
- [X] T025 [US2] Run the focused User Story 2 tests in `test/models/financial/plan_test.rb`, `test/controllers/financial/plans/planned_transaction_orders_controller_test.rb`, `test/models/financial/planned_transaction_test.rb`, `test/models/financial/plan/projection_test.rb`, `test/services/financial/planned_transactions/apply_service_test.rb`, `test/components/ui/button_component_test.rb`, and `test/system/financial_plan_execution_test.rb`

**Checkpoint**: Custom order persists, due-date view is non-destructive, and both pointer and keyboard users can reorder without changing actual transactions.

---

## Phase 5: User Story 3 - Verify and Correct the Account Route (Priority: P2)

**Goal**: Show each route where it is used and permit corrections through the existing edit flow.

**Independent Test**: Review and correct expense, transfer, liability-payment, and liability-charge routes, including an applied movement; verify only the planned route changes and each funding source shows its destination inline.

### Tests for User Story 3

- [X] T026 [P] [US3] Add failing route-selector, movement-kind re-derivation, applied-correction, account-scoping, and linked-actual immutability tests in `test/controllers/financial/plans_controller_test.rb` and `test/models/financial/planned_transaction_test.rb`
- [X] T027 [P] [US3] Add failing funding-source destination badge and no-separate-summary assertions in `test/controllers/financial/plans_controller_test.rb`

### Implementation for User Story 3

- [X] T028 [US3] Render explicit complete and missing route descriptions beside planned movements in `app/models/financial/planned_transaction.rb` and `app/views/financial/plans/_planned_transactions.html.erb`
- [X] T029 [US3] Permit planned-route corrections after application while preserving linked actual entries in `app/models/planned_expense.rb` and `app/models/financial/planned_transaction.rb`
- [X] T030 [US3] Accept account-scoped route updates through the existing planned-movement resource in `app/controllers/financial/planned_transactions_controller.rb` and `config/routes.rb`
- [X] T031 [US3] Add movement-kind-specific source and destination selectors to the existing edit flow in `app/views/financial/plans/_planned_transactions.html.erb`
- [X] T032 [US3] Add a destination badge to each existing funding-source item and remove the separate account summary in `app/views/financial/plans/_funding_sources.html.erb`
- [X] T033 [US3] Run the focused User Story 3 tests in `test/models/financial/planned_transaction_test.rb` and `test/controllers/financial/plans_controller_test.rb`

**Checkpoint**: Users can see and correct every required planned route without changing historical actual entries.

---

## Phase 6: User Story 4 - Separate Portfolio and Plan Decisions (Priority: P3)

**Goal**: Keep plan details plan-local while the plans overview aggregates only the displayed plans with the same planned-consumption rule.

**Independent Test**: Filter the plans overview, compare its totals with an individual plan, and verify overview Planned Consumption applies the same Reserve funds predicate without mixing scopes.

### Tests for User Story 4

- [X] T034 [P] [US4] Add failing overview expense, reserved-neutral, unreserved-neutral, and filtered-plan total tests in `test/models/financial/plans/overview_test.rb`
- [X] T035 [P] [US4] Add failing overview-versus-plan labeling and planned-for ordering assertions in `test/controllers/financial/plans_controller_test.rb`

### Implementation for User Story 4

- [X] T036 [US4] Keep actual calculations plan-local and remove preceding-plan carryover in `app/models/financial/plan/actuals.rb`
- [X] T037 [US4] Reuse the shared plan-balance predicate for overview Planned Consumption in `app/models/financial/plans/overview.rb`
- [X] T038 [US4] Present clearly scoped overview labels while preserving planned-for ordering in `app/views/financial/plans/index.html.erb`
- [X] T039 [US4] Run the focused User Story 4 tests in `test/models/financial/plans/overview_test.rb`, `test/models/financial/plan/actuals_test.rb`, and `test/controllers/financial/plans_controller_test.rb`

**Checkpoint**: Overview figures and individual-plan figures are independently correct and clearly distinguishable.

---

## Phase 7: Polish and Cross-Cutting Verification

**Purpose**: Verify the living specification without broadening scope.

- [X] T040 Execute the manual acceptance walkthrough and record only verified corrections in `specs/003-quincena-plan-execution/quickstart.md`
- [X] T041 Run `bin/rails test`, `npm run herb:lint`, and `bin/rubocop` for the implementation paths listed in `specs/003-quincena-plan-execution/plan.md`
- [X] T042 Run `bin/brakeman --no-pager` and verify account scoping against `specs/003-quincena-plan-execution/contracts/http.md`

---

## Dependencies and Execution Order

### Phase Dependencies

- **Setup and Foundation**: Already complete; they establish the regression baseline and plan-owned namespace.
- **US1**: First remaining slice and the MVP; its shared predicate feeds US4.
- **US2**: Existing ordering is functional; compact controls can proceed independently of US1 after T017.
- **US3**: Can proceed independently after its tests; T029 precedes T030 and T031.
- **US4**: T037 depends on T008; presentation work can proceed independently.
- **Polish**: Depends on every selected story.

### User Story Dependency Graph

```text
Foundation
├── US1 Planned and actual execution totals
│   └── US4 Portfolio totals
├── US2 Execution priority
└── US3 Account routes
```

### Within Each User Story

- Add and run the focused failing tests before implementation.
- Implement shared domain behavior before controller and view changes.
- Reuse existing persistence, controllers, components, and browser behavior.
- Run the story's focused tests before its checkpoint.

### Parallel Opportunities

- US1 tests T004-T007 can run in parallel.
- US2 compact-control test T017 can run alongside US1.
- US3 tests T026-T027 can run in parallel and alongside US1.
- US4 tests T034-T035 can run in parallel; T037 waits for T008.

---

## Parallel Examples

### User Story 1

```text
Task T004: Projection calculations in test/models/financial/plan/projection_test.rb
Task T005: Reserve funds rules in model tests
Task T006: Actual calculations in test/models/financial/plan/actuals_test.rb
Task T007: Summary and control presentation in controller tests
```

### User Story 3

```text
Task T026: Planned route correction tests
Task T027: Funding destination presentation tests
```

### User Story 4

```text
Task T034: Overview calculation tests
Task T035: Overview presentation tests
```

---

## Implementation Strategy

### MVP First

1. Complete T004-T014 for User Story 1.
2. Validate the metric-card summary and Reserve funds behavior independently.
3. Stop before optional lower-priority stories if a smaller release is desired.

### Incremental Delivery

1. **US1** makes plan calculations match the clarified financial rules.
2. **US2** compacts the already-working priority controls.
3. **US3** removes route-correction guesswork with the existing edit flow.
4. **US4** aligns portfolio totals with the same shared predicate.
5. **Polish** validates the complete living specification.

### Minimality Rules

- Do not add tables, dependencies, generic sortable abstractions, or duplicate calculation classes.
- Keep `planned_for` as reference and ordering data only; never constrain plan membership by date.
- Keep persisted `commits_plan_funds`; expose it as Reserve funds instead of renaming the column.
- Reuse the existing movement edit flow, funding-source item, button component, and reorder endpoint.
- Never mutate linked actual entries when planned order, route, or Reserve funds changes.

## Notes

- Checked tasks are already implemented and still valid under the clarified specification.
- Checkpoints are validation boundaries, not commit instructions.

## Phase 8: Unplanned Actual Consumption

- [X] T043 [US1] Characterize unplanned plan expenses in `test/models/financial/plan/actuals_test.rb`, explain their Actual Consumption effect in `app/views/financial/plans/_actual_entries.html.erb`, and verify the plan page in `test/controllers/financial/plans_controller_test.rb`
