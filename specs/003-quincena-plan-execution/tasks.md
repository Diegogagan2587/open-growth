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

- [X] T001 Run the existing baseline tests in `test/models/financial/plan_projection_test.rb`, `test/models/financial/plan_actuals_test.rb`, `test/models/financial/plan_test.rb`, `test/models/financial/planned_transaction_test.rb`, `test/controllers/financial/plans_controller_test.rb`, and `test/services/financial/planned_transactions/apply_service_test.rb`

---

## Phase 2: Foundational Namespaces

**Purpose**: Establish the plan-owned model boundaries used by every story without changing behavior.

**⚠️ CRITICAL**: Complete this phase before user-story implementation.

- [X] T002 Move `Financial::PlanProjection` to `Financial::Plan::Projection` in `app/models/financial/plan/projection.rb`, move its tests to `test/models/financial/plan/projection_test.rb`, and update references in `app/controllers/financial/plans_controller.rb`
- [X] T003 Move `Financial::PlanActuals` to `Financial::Plan::Actuals` in `app/models/financial/plan/actuals.rb`, move its tests to `test/models/financial/plan/actuals_test.rb`, and update references in `app/controllers/financial/plans_controller.rb`

**Checkpoint**: Existing behavior passes under the plan-owned namespaces with no compatibility duplicate classes.

---

## Phase 3: User Story 1 - Know Whether the Plan Is Funded (Priority: P1) 🎯 MVP

**Goal**: Show current money available from selected plan accounts, pending money required, exact remainder or shortfall, and an honest completeness state without double-counting applied movements.

**Independent Test**: Open a plan with selected destination assets, pending payments, an applied payment, and movements outside the plan reference date; verify account balances reconcile to available money, only pending cash requirements compose required money, and remainder or shortfall is exact.

### Tests for User Story 1

- [X] T004 [P] [US1] Replace legacy carryover expectations with failing current-balance, selected-account deduplication, pending-only, transfer, applied-movement, missing-account, and flexible-date tests in `test/models/financial/plan/projection_test.rb`
- [X] T005 [P] [US1] Add failing cash-requirement classification tests for pending outflows, liability payments, transfers, liability charges, and applied movements in `test/models/financial/planned_transaction_test.rb`
- [X] T006 [P] [US1] Add failing plan-page assertions for account-level availability, required money, remainder, shortfall, balance-basis labeling, and incomplete states in `test/controllers/financial/plans_controller_test.rb`

### Implementation for User Story 1

- [X] T007 [US1] Add pending cash-requirement behavior to `app/models/financial/planned_transaction.rb` without using `commits_plan_funds` as the execution-total switch
- [X] T008 [US1] Implement selected funding accounts, current available money, pending required money, completeness, remainder/shortfall, and ordered row balances in `app/models/financial/plan/projection.rb`
- [X] T009 [US1] Load the plan-local projection and its ordered movements in `app/controllers/financial/plans_controller.rb`
- [X] T010 [US1] Replace forecast/carryover metrics with current execution metrics and selected-account contributions in `app/views/financial/plans/_metrics.html.erb` and `app/views/financial/plans/_funding_sources.html.erb`
- [X] T011 [US1] Run the focused User Story 1 tests in `test/models/financial/plan/projection_test.rb`, `test/models/financial/planned_transaction_test.rb`, and `test/controllers/financial/plans_controller_test.rb`

**Checkpoint**: The plan independently answers “what money do I have, what remains to pay, and what is missing?” using only that plan's membership.

---

## Phase 4: User Story 2 - Prioritize and Execute Payments (Priority: P1)

**Goal**: Persist a custom order for all planned movements, switch between custom and due-date views, recalculate each row balance, and preserve planned versus actual dates during payment.

**Independent Test**: Reorder pending and applied movements across due dates, reload, switch to due-date order and back, add a movement, and apply one movement on an earlier or later date; verify custom priority persists, row balances follow the visible order, and the actual entry is unchanged by reorder.

### Tests for User Story 2

- [X] T012 [P] [US2] Add failing atomic reorder tests for complete ID validation, duplicate/foreign/missing IDs, contiguous positions, applied movements, rollback, and append-after-custom-order in `test/models/financial/plan_test.rb`
- [X] T013 [P] [US2] Add failing order endpoint tests for account scoping, successful redirect, invalid payload rollback, and actual-entry immutability in `test/controllers/financial/plans/planned_transaction_orders_controller_test.rb`
- [X] T014 [P] [US2] Add failing due-date/custom ordering, stable tie, unscheduled-last, and payment-timing tests in `test/models/financial/planned_transaction_test.rb` and `test/models/financial/plan/projection_test.rb`
- [X] T015 [P] [US2] Add failing due-date default, earlier/later override, and planned-date preservation tests in `test/components/financial/installment_payment_form_component_test.rb` and `test/services/financial/planned_transactions/apply_service_test.rb`
- [X] T016 [P] [US2] Add failing plan-page assertions for one-interaction sort switching, accessible reorder controls, actual date, timing badge, payment notes, and per-row balances in `test/controllers/financial/plans_controller_test.rb`
- [X] T017 [P] [US2] Add a failing reorder/sort/application interaction test in `test/system/financial_plan_execution_test.rb`

### Implementation for User Story 2

- [X] T018 [US2] Add the reversible `custom_ordered` boolean migration for `income_events` in `db/migrate/*_add_custom_ordered_to_income_events.rb` and update `db/schema.rb`
- [X] T019 [US2] Implement default order selection and transactional `reorder_planned_transactions!` with plan locking and temporary positions in `app/models/financial/plan.rb`
- [X] T020 [US2] Add the singular nested order route in `config/routes.rb` and account-scoped update action in `app/controllers/financial/plans/planned_transaction_orders_controller.rb`
- [X] T021 [US2] Accept only `custom` and `due_date` view modes and pass the selected mode into projection ordering in `app/controllers/financial/plans_controller.rb` and `app/models/financial/plan/projection.rb`
- [X] T022 [US2] Add custom/due-date switch links, full-order submission, keyboard move controls, payment notes, actual dates, timing badges, and selected-order row balances in `app/views/financial/plans/_planned_transactions.html.erb`
- [X] T023 [US2] Add dependency-free drag enhancement that submits the same full ordered-ID form while retaining keyboard controls in `app/javascript/controllers/planned_transaction_order_controller.js`
- [X] T024 [US2] Default actual dates from due date before planned date while preserving user overrides in `app/components/financial/installment_payment_form_component.rb` and `app/services/financial/planned_transactions/apply_service.rb`
- [X] T025 [US2] Add derived early/on-time/late behavior and optional payment-note permitting in `app/models/financial/planned_transaction.rb` and `app/controllers/financial/planned_transactions_controller.rb`
- [X] T026 [US2] Run all User Story 2 tests in `test/models/financial/plan_test.rb`, `test/models/financial/plan/projection_test.rb`, `test/models/financial/planned_transaction_test.rb`, `test/controllers/financial/plans/planned_transaction_orders_controller_test.rb`, `test/controllers/financial/plans_controller_test.rb`, `test/components/financial/installment_payment_form_component_test.rb`, `test/services/financial/planned_transactions/apply_service_test.rb`, and `test/system/financial_plan_execution_test.rb`

**Checkpoint**: Custom priority is durable, due-date view is non-destructive, every visible order has correct running balances, and actual ledger facts never change during reorder.

---

## Phase 5: User Story 3 - Verify the Account Route (Priority: P2)

**Goal**: Make every movement's source, destination, direction, and missing route information visible without leaving the plan.

**Independent Test**: Open a plan containing expense, liability-payment, liability-charge, transfer, and incomplete routes; verify every complete direction is explicit and every missing side is identified.

### Tests for User Story 3

- [X] T027 [P] [US3] Add failing complete and incomplete route-description tests in `test/models/financial/planned_transaction_test.rb`
- [X] T028 [P] [US3] Add failing plan-page assertions for source, destination, direction, and missing-route labels in `test/controllers/financial/plans_controller_test.rb`

### Implementation for User Story 3

- [X] T029 [US3] Replace nullable route summaries with explicit route presentation and completeness behavior in `app/models/financial/planned_transaction.rb`
- [X] T030 [US3] Render route direction and missing-side states beside every planned movement in `app/views/financial/plans/_planned_transactions.html.erb`
- [X] T031 [US3] Run the focused User Story 3 tests in `test/models/financial/planned_transaction_test.rb` and `test/controllers/financial/plans_controller_test.rb`

**Checkpoint**: The plan is sufficient to execute each movement through the intended accounts without guessing.

---

## Phase 6: User Story 4 - Separate Portfolio and Plan Decisions (Priority: P3)

**Goal**: Keep individual-plan calculations plan-local while presenting clearly labeled forecast totals for the account-scoped plans currently shown on the overview.

**Independent Test**: Create multiple plans with different reference dates and movements outside those dates; verify one plan shows only its own execution figures while the filtered overview totals all and only the displayed plans.

### Tests for User Story 4

- [X] T032 [P] [US4] Replace preceding-plan carryover expectations with failing plan-local actual-entry tests in `test/models/financial/plan/actuals_test.rb`
- [X] T033 [P] [US4] Add failing filtered plan-count, expected-funding, pending-requirement, and net-position tests in `test/models/financial/plans/overview_test.rb`
- [X] T034 [P] [US4] Add failing overview-versus-plan labeling, filtering, and planned-for ordering assertions in `test/controllers/financial/plans_controller_test.rb`

### Implementation for User Story 4

- [X] T035 [US4] Remove preceding-plan carryover and keep actual calculations plan-local in `app/models/financial/plan/actuals.rb`
- [X] T036 [US4] Implement collection forecast totals for an account-scoped plans relation in `app/models/financial/plans/overview.rb`
- [X] T037 [US4] Load overview calculations after applying month/status filters in `app/controllers/financial/plans_controller.rb`
- [X] T038 [US4] Add clearly labeled portfolio forecast metrics while preserving planned-for display ordering in `app/views/financial/plans/index.html.erb`
- [X] T039 [US4] Run the focused User Story 4 tests in `test/models/financial/plan/actuals_test.rb`, `test/models/financial/plans/overview_test.rb`, and `test/controllers/financial/plans_controller_test.rb`

**Checkpoint**: Overview forecasts and individual-plan execution figures are independently correct and cannot be mistaken for each other.

---

## Phase 7: Polish and Cross-Cutting Verification

**Purpose**: Validate the complete living specification without expanding feature scope.

- [ ] T040 Execute the manual acceptance walkthrough and record any specification correction in `specs/003-quincena-plan-execution/quickstart.md`
- [ ] T041 Run `bin/rails test`, `npm run herb:lint`, and `bin/rubocop` against the implementation paths listed in `specs/003-quincena-plan-execution/plan.md`
- [X] T042 Run `bin/brakeman --no-pager` and verify account-scoped financial lookups against `specs/003-quincena-plan-execution/contracts/http.md`

---

## Dependencies and Execution Order

### Phase Dependencies

- **Phase 1 (Setup)**: Starts immediately and establishes the regression baseline.
- **Phase 2 (Foundational)**: Depends on Phase 1 and blocks all user stories.
- **Phase 3 (US1)**: Depends on Phase 2 and is the MVP.
- **Phase 4 (US2)**: Depends on US1 because its running balances use the new execution projection.
- **Phase 5 (US3)**: Depends on US1 for selected-account context; its route behavior can otherwise be developed independently of US2.
- **Phase 6 (US4)**: Depends on US1's pending cash-requirement semantics but not on US2 or US3.
- **Phase 7 (Polish)**: Depends on every story selected for release.

### User Story Dependency Graph

```text
Foundation
    └── US1 Know whether the plan is funded
        ├── US2 Prioritize and execute payments
        ├── US3 Verify the account route
        └── US4 Separate portfolio and plan decisions
```

### Within Each User Story

- Write the story's focused tests and confirm expected failures before implementation.
- Implement model/domain behavior before controller coordination.
- Implement controller contracts before view interaction.
- Run the story's focused test set before its checkpoint.
- Reuse existing fixtures when representative; create inline records only for scenario-specific financial states.

### Parallel Opportunities

- Within US1, T004, T005, and T006 can run in parallel.
- Within US2, T012 through T017 can be authored in parallel before implementation.
- Within US3, T027 and T028 can run in parallel.
- Within US4, T032, T033, and T034 can run in parallel.
- After US1, US2, US3, and US4 can be assigned in parallel if changes to shared files are coordinated; US3 and US4 have no behavioral dependency on US2.

---

## Parallel Examples

### User Story 1

```text
Task T004: Projection calculation tests in test/models/financial/plan/projection_test.rb
Task T005: Cash-requirement tests in test/models/financial/planned_transaction_test.rb
Task T006: Plan-page metric tests in test/controllers/financial/plans_controller_test.rb
```

### User Story 2

```text
Task T012: Aggregate reorder tests in test/models/financial/plan_test.rb
Task T013: HTTP order tests in test/controllers/financial/plans/planned_transaction_orders_controller_test.rb
Task T015: Actual-date tests in component and service test files
```

### User Story 3

```text
Task T027: Route domain tests in test/models/financial/planned_transaction_test.rb
Task T028: Route presentation tests in test/controllers/financial/plans_controller_test.rb
```

### User Story 4

```text
Task T032: Plan-local actual tests in test/models/financial/plan/actuals_test.rb
Task T033: Overview calculation tests in test/models/financial/plans/overview_test.rb
Task T034: Overview presentation tests in test/controllers/financial/plans_controller_test.rb
```

---

## Implementation Strategy

### MVP First

1. Complete Phase 1 and Phase 2.
2. Complete User Story 1.
3. Stop and validate the funding calculation independently.
4. Demo the plan's current available money, pending required money, remainder/shortfall, and no-double-counting rule.

### Incremental Delivery

1. **US1** makes the plan financially truthful.
2. **US2** makes that truthful plan executable in user-selected priority.
3. **US3** removes account-routing guesswork.
4. **US4** restores useful portfolio context without contaminating one plan.
5. Run cross-cutting verification after the desired stories are complete.

### Minimality Rules

- Do not add a new dependency, generic sortable abstraction, repository layer, or parallel financial table.
- Do not rename `Financial::PlannedTransaction` or `Financial::FundingSource` merely to place them below `Financial::Plan`.
- Do not refactor close, cancel, move, receive, or unrelated legacy workflows unless a failing feature test proves it necessary.
- Prefer existing UI components and native browser behavior; drag remains an enhancement over keyboard controls.

## Notes

- `[P]` tasks touch separate files or are otherwise safe to execute concurrently.
- Every story task includes `[US1]`, `[US2]`, `[US3]`, or `[US4]` for traceability.
- Commit only when explicitly requested; checkpoints are validation boundaries, not commit instructions.

## Phase 8: Convergence

- [X] T043 [US4] Implement the account-scoped `Financial::Plans::Overview`, load it after month/status filtering, and render clearly labeled portfolio totals in `app/models/financial/plans/overview.rb`, `app/controllers/financial/plans_controller.rb`, and `app/views/financial/plans/index.html.erb` per US4/AC1-3 and FR-018/019 (missing)
- [X] T044 [US4] Remove preceding-plan carryover from `Financial::Plan::Actuals#opening_balance` and complete the plan-local actuals boundary tests in `app/models/financial/plan/actuals.rb` and `test/models/financial/plan/actuals_test.rb` per FR-017 and plan Slice 4.1 (contradicts)
- [X] T045 [US1] Reconcile projection/controller test coverage and visible balance-basis assertions with funding-source effective amounts, actual-receipt precedence, applied cash deductions, and immunity to negative account balances in `test/models/financial/plan/projection_test.rb` and `test/controllers/financial/plans_controller_test.rb` per FR-002/003/016/022 and SC-004/007 (partial)
- [ ] T046 Run the remaining User Story 4 tests, full Rails suite, Herb lint, RuboCop, Brakeman, and the manual acceptance walkthrough; record only verified corrections in `specs/003-quincena-plan-execution/quickstart.md` per Constitution IV and plan Verification Strategy (partial)
