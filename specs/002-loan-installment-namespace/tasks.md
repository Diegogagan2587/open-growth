---

description: "Implementation tasks for the loan installment domain and schedule management"
---

# Tasks: Loan Installment Domain and Schedule Management

**Input**: Design documents from `/specs/002-loan-installment-namespace/`

**Prerequisites**: `plan.md`, `spec.md`, `research.md`, `data-model.md`, `contracts/`, and `quickstart.md`

**Tests**: Included because the specification and project constitution require focused test-first coverage for financial domain rules, workflow contracts, and user-visible behavior.

**Scope note**: The namespace rename must preserve the existing table and financial data. The transferred schedule requirements add first-payment anchoring, manual due dates, explicit planned-record consent, and protected actual transaction history. Extra-payment events and configurable interest policies remain a separately planned slice.

## Phase 1: Setup (Shared Infrastructure)

**Purpose**: Establish the implementation baseline and inspect existing Rails conventions before modifying the loan domain.

- [X] T001 Inspect the existing installment model, loan associations, schedule generation, regeneration, planned-transaction, payment, loan-view, component, and test patterns in `app/models/financial/`, `app/services/financial/loans/`, `app/controllers/financial/loans/`, `app/views/financial/loans/`, `app/javascript/controllers/`, and `test/`
- [X] T002 Run the focused baseline commands from `specs/002-loan-installment-namespace/quickstart.md` and record pre-existing failures in `specs/002-loan-installment-namespace/quickstart.md`

---

## Phase 2: Foundational (Blocking Prerequisites)

**Purpose**: Set the compatibility and domain boundaries that all user stories depend on.

**⚠️ CRITICAL**: Complete this phase before user-story implementation.

- [X] T003 Confirm the existing `financial_loan_installments` table, columns, indexes, foreign keys, and fixture usage in `db/schema.rb`, `app/models/financial/loan_installment.rb`, and `test/fixtures/`
- [X] T004 Define the namespace migration map and caller inventory in `specs/002-loan-installment-namespace/research.md`, including the no-table-migration rule and the no-undocumented-alias rule
- [X] T005 Add focused test fixtures or factory support only where required for installment, planned transaction, actual payment, and manual-date scenarios in `test/fixtures/` or the existing test setup files

**Checkpoint**: Existing persistence and representative test data are understood; all story work can preserve the current financial boundaries.

---

## Phase 3: User Story 1 - Use a Clear Loan-Owned Installment Model (Priority: P1) 🎯 MVP

**Goal**: Replace `Financial::LoanInstallment` with the canonical `Financial::Loan::Installment` model without changing persistence or behavior.

**Independent Test**: Boot Rails, load `Financial::Loan::Installment`, read/write an existing `financial_loan_installments` row, and run the focused loan-installment association tests with no obsolete constant required.

### Tests for User Story 1

- [X] T006 [P] [US1] Add autoload, table-name, persistence, and obsolete-constant assertions in `test/models/financial/loan_installment_test.rb`
- [X] T007 [P] [US1] Add loan association and inverse/foreign-key coverage for `Financial::Loan::Installment` in `test/models/financial/loan_test.rb`
- [X] T008 [P] [US1] Add boot and caller-reference coverage proving the canonical constant loads without a competing model in `test/models/financial/loan_installment_test.rb` and `test/services/financial/loans/installment_workflow_test.rb`

### Implementation for User Story 1

- [X] T009 [US1] Move the model implementation to `app/models/financial/loan/installment.rb`, define `Financial::Loan::Installment`, preserve the `financial_loan_installments` table mapping, and remove the obsolete top-level model file
- [X] T010 [US1] Update the loan association and dependent/inverse declarations to reference `Financial::Loan::Installment` in `app/models/financial/loan.rb`
- [X] T011 [P] [US1] Update installment references, class names, and constantized associations in `app/services/financial/loans/`, `app/controllers/financial/loans/`, `app/models/financial/`, and `app/views/financial/loans/`
- [X] T012 [P] [US1] Move or rename focused model tests to `test/models/financial/loan/installment_test.rb` and update all assertions to the canonical constant
- [X] T013 [US1] Update workflow, controller, component, and integration test references to `Financial::Loan::Installment` in `test/services/financial/loans/`, `test/controllers/financial/loans/`, and `test/components/`

**Checkpoint**: The namespaced model is the only canonical installment model, existing rows still load, and all callers use the new constant.

---

## Phase 4: User Story 2 - Configure an Accurate Payment Schedule (Priority: P1)

**Goal**: Preserve the different-payment position behavior and make `first_payment_date` the explicit contractual schedule anchor.

**Independent Test**: Generate beginning/final and one-payment schedules with a receipt date before the first payment date, then verify ordering, dates, totals, and compatibility defaults.

### Tests for User Story 2

- [X] T014 [P] [US2] Add beginning/final/default/one-payment/invalid-position and reconciliation coverage for `different_payment_amount` and `different_payment_position` in `test/models/financial/loans/repayment_terms_test.rb`
- [X] T015 [P] [US2] Add persisted mapping, compatibility-default, and `first_payment_date` validation coverage in `test/models/financial/loan_test.rb`
- [X] T016 [P] [US2] Add schedule-anchor, frequency-derived-date, paid-prefix, and existing-schedule-preservation coverage in `test/models/financial/loans/amortization_schedule_test.rb` and `test/services/financial/loans/repayment_workflows_test.rb`
- [X] T017 [P] [US2] Add request and rendered-form coverage for `different_payment_position`, `different_payment_amount`, and the clearly described `First payment date` field in `test/controllers/financial/loans_controller_test.rb`

### Implementation for User Story 2

- [X] T018 [US2] Add a reversible nullable `first_payment_date` migration to `db/migrate/` and update `db/schema.rb` without rewriting existing installment dates
- [X] T019 [US2] Update `app/models/financial/loan.rb` and `app/models/financial/loans/repayment_terms.rb` to validate and expose the neutral different-payment fields, default position to `final`, and pass the first-payment anchor into schedule generation
- [X] T020 [US2] Update `app/models/financial/loans/amortization_schedule.rb` and `app/services/financial/loans/regenerate_schedule.rb` to use `first_payment_date`, preserve existing dates until explicit regeneration, and retain financial reconciliation
- [X] T021 [US2] Update permitted parameters and repayment-change detection in `app/controllers/financial/loans_controller.rb` for the neutral payment fields and `first_payment_date`
- [X] T022 [US2] Update `app/views/financial/loans/_form.html.erb`, `app/views/financial/loans/show.html.erb`, and `app/javascript/controllers/loan_terms_controller.js` with the first-payment label, supporting explanation, and accurate payment-position estimate

**Checkpoint**: New schedules use the first contractual payment date and preserve the established different-payment financial behavior.

---

## Phase 5: User Story 3 - Correct Due Dates with Explicit Impact Choices (Priority: P1)

**Goal**: Let users edit one installment due date from the loan view and approve linked planned/manual-date effects individually while protecting actual records.

**Independent Test**: Exercise an unlinked installment, a pending planned transaction, a paid installment, cancellation, stale confirmation, and selective manual-date reset; verify no unintended neighboring or actual-date changes.

### Tests for User Story 3

- [X] T023 [P] [US3] Add direct-edit, date-order, neighboring-date, paid-installment, and manual-date marker tests in `test/models/financial/loan/installment_test.rb`
- [X] T024 [P] [US3] Add impact-summary, independent-choice, cancellation, stale-state, lock, and atomicity coverage in `test/services/financial/loans/installment_workflow_test.rb`
- [X] T025 [P] [US3] Add planned due-date synchronization and actual-entry date/history preservation coverage in `test/models/financial/planned_transaction_test.rb`, `test/models/financial/entry_test.rb`, and `test/services/financial/loans/repayment_workflows_test.rb`
- [X] T026 [P] [US3] Add request/response coverage for one summary, per-record choices, actionable validation, and stale confirmation in `test/controllers/financial/loans/installment_payments_controller_test.rb` or the existing loan schedule controller test boundary
- [X] T027 [P] [US3] Add user-visible accessibility and interaction coverage for installment date editing and the impact summary in `test/components/` or `test/system/`

### Implementation for User Story 3

- [X] T028 [US3] Add a reversible `manual_due_date` migration and model behavior in `db/migrate/` and `app/models/financial/loan/installment.rb`, preserving existing dates with a generated-date default
- [X] T029 [US3] Implement installment due-date validation, manual-date marking, impact calculation, locking, stale-state recheck, and atomic selected updates in `app/models/financial/loan/installment.rb` or the smallest existing loan-domain workflow boundary
- [X] T030 [US3] Implement resource-oriented installment due-date update and reset request handling in `app/controllers/financial/loans/schedules_controller.rb` or `app/controllers/financial/loans/installment_payments_controller.rb`, keeping business rules out of controllers
- [X] T031 [US3] Synchronize only explicitly approved planned-record due-date fields and preserve actual payment/application dates in `app/services/financial/loans/plan_installment_service.rb`, `app/services/financial/planned_transactions/`, and the associated domain models
- [X] T032 [US3] Add the loan-view installment date control, one impact summary, independent choices, cancel/stale feedback, and protected-actual-record messaging in `app/views/financial/loans/show.html.erb`, relevant partials/components, and `app/javascript/controllers/`
- [X] T033 [US3] Update schedule regeneration to preserve manual dates by default and expose a selective per-installment reset in `app/services/financial/loans/regenerate_schedule.rb` and its request/UI boundary

**Checkpoint**: Due-date changes are explicit, atomic, independently reviewable, and never rewrite actual payment/application history.

---

## Phase 6: User Story 4 - Preserve Loan Workflows During the Rename (Priority: P1)

**Goal**: Prove schedule generation, planning, payment application, reporting, totals, and ownership checks remain behaviorally unchanged after the namespace and schedule work.

**Independent Test**: Run the complete focused loan workflow suite against generated, planned, paid, regenerated, and account-scoped installments and compare financial values and links.

### Tests for User Story 4

- [X] T034 [P] [US4] Add end-to-end namespace regression coverage for generate, regenerate, plan, apply payment, and account ownership workflows in `test/services/financial/loans/repayment_workflows_test.rb` and `test/services/financial/loans/installment_workflow_test.rb`
- [X] T035 [P] [US4] Add controller/view regression coverage for loan show, schedule, planned links, actual payment links, and unchanged totals in `test/controllers/financial/loans_controller_test.rb` and `test/controllers/financial/loans/schedules_controller_test.rb`
- [X] T036 [P] [US4] Add persistence/restart-style coverage proving existing rows remain readable and writable with unchanged associations in `test/models/financial/loan/installment_test.rb`

### Implementation for User Story 4

- [X] T037 [US4] Update remaining reporting, payment, planning, and account-scoping callers to use `Financial::Loan::Installment` in `app/services/financial/`, `app/controllers/financial/`, `app/models/financial/`, and `app/views/financial/`
- [X] T038 [US4] Remove obsolete constant references and verify no second canonical installment class remains with `rg` checks and the Rails autoload test boundary in `test/models/financial/loan/installment_test.rb`
- [X] T039 [US4] Reconcile schedule regeneration and payment-application behavior with the transferred due-date invariants in `app/services/financial/loans/regenerate_schedule.rb` and `app/services/financial/loans/apply_installment_payment.rb`

**Checkpoint**: All supported loan workflows use the namespaced model and preserve financial values, links, resolutions, and account ownership.

---

## Phase 7: Polish & Cross-Cutting Concerns

**Purpose**: Run required quality gates, verify documentation alignment, and keep explicitly deferred requirements visible.

- [X] T040 [P] Update `specs/002-loan-installment-namespace/data-model.md`, `specs/002-loan-installment-namespace/contracts/loan-simulation-ui.md`, and `specs/002-loan-installment-namespace/quickstart.md` when implementation names or verification commands differ
- [X] T041 [P] Run the focused Rails model, workflow, request, and integration tests from `specs/002-loan-installment-namespace/quickstart.md` and resolve regressions without changing financial meaning
- [X] T042 [P] Run Herb lint against modified loan ERB files, including `app/views/financial/loans/show.html.erb` and `app/views/financial/loans/_form.html.erb`, and resolve accessibility/template failures
- [X] T043 [P] Run the repository's applicable Ruby lint, security/data-safety, and migration checks for the changed loan domain and record unrelated failures separately
- [X] T044 Verify `FR-018` remains explicitly deferred and separately tracked in `specs/002-loan-installment-namespace/spec.md` and `specs/002-loan-installment-namespace/plan.md`; do not claim extra-payment or interest-policy implementation in this feature
- [X] T045 Run the complete quickstart scenarios in `specs/002-loan-installment-namespace/quickstart.md`, including stale confirmation and selective reset, and record the verification in the implementation handoff

---

## Dependencies & Execution Order

### Phase Dependencies

- **Setup (Phase 1)**: No implementation dependency; establishes the baseline.
- **Foundational (Phase 2)**: Depends on Setup and blocks all user stories.
- **US1 (Phase 3)**: Depends on the foundational model/table inventory and is the MVP namespace slice.
- **US2 (Phase 4)**: Depends on US1's canonical installment references and existing repayment APIs.
- **US3 (Phase 5)**: Depends on US1's namespaced installment and US2's schedule/date anchor.
- **US4 (Phase 6)**: Depends on US1–US3 and validates their combined workflow behavior.
- **Polish (Phase 7)**: Depends on all selected user stories being complete.

### User Story Dependencies

- **US1 (P1)**: Can start after Foundational; no dependency on schedule UX.
- **US2 (P1)**: Depends on US1 so schedule/installment references use the canonical model.
- **US3 (P1)**: Depends on US1 and US2 because due-date editing modifies generated installments and schedule regeneration.
- **US4 (P1)**: Depends on all prior stories and serves as the cross-workflow regression slice.

### Parallel Opportunities

- T006–T008 can run in parallel because they cover separate namespace boundaries.
- T014–T017 can run in parallel after the repayment field contract is agreed.
- T023–T027 can run in parallel across model, workflow, persistence, request, and UI boundaries.
- T034–T036 can run in parallel after the combined behavior is implemented.
- T040–T043 can run in parallel during polish.

### Within Each User Story

- Write or update focused tests first and confirm expected failures before implementation.
- Complete domain/model invariants before controller and UI integration.
- Complete workflow atomicity before user-visible confirmation polish.
- Stop at each checkpoint and run the story's independent test criteria.

## Parallel Example: User Story 3

```text
Task T023: Installment model date invariants in test/models/financial/loan/installment_test.rb
Task T024: Impact workflow and stale-state tests in test/services/financial/loans/installment_workflow_test.rb
Task T025: Planned/actual record preservation tests in test/models/financial/ and test/services/financial/loans/
Task T027: Impact-summary interaction coverage in test/components/ or test/system/
```

## Implementation Strategy

### MVP First

1. Complete Setup and Foundational phases.
2. Complete US1: canonical namespaced model, associations, callers, and autoload tests.
3. Stop and validate existing loan records and workflow behavior independently.

### Incremental Delivery

1. Add US2 schedule anchor and payment-position coverage.
2. Add US3 due-date editing, impact summary, planned consent, and manual reset.
3. Add US4 combined workflow regression coverage.
4. Run polish and quality gates, keeping FR-018 explicitly deferred.

## Notes

- Every task uses `- [ ] T###`, includes a concrete repository path, and has a story label in user-story phases.
- `[P]` marks tasks that can proceed independently without modifying the same primary file.
- No table rename or data migration is permitted for the Ruby namespace change.
- Controllers coordinate requests; financial invariants and atomic transitions remain in the owning domain/workflow boundary.

---

## Phase 8: Convergence

**Purpose**: Resolve the payment-amount schedule failure discovered against the persisted loan #8 example.

- [X] T046 [US2] Define and implement the domain rule for a beginning exceptional payment that is lower than accrued interest, preserving financial reconciliation and the documented payment-position semantics in `app/models/financial/loans/repayment_terms.rb` and `app/models/financial/loans/amortization_schedule.rb` (FR-011, US2/AC1, partial)
- [X] T047 [P] [US2] Add regression coverage for loan #8’s shape—principal `5000`, six monthly payments, beginning amount `50`, regular amount `1311`—plus nearby valid and invalid beginning-payment cases in `test/models/financial/loans/amortization_schedule_test.rb` and `test/models/financial/loans/repayment_terms_test.rb` (SC-006, missing)
- [X] T048 [US2] Replace the generic schedule-generation failure with an actionable message that reports the installment, accrued interest, entered payment, and correction guidance in `app/models/financial/loans/amortization_schedule.rb`, `app/services/financial/loans/regenerate_schedule.rb`, `app/controllers/financial/loans/schedules_controller.rb`, and `app/views/financial/loans/show.html.erb` (US2/AC1, partial)

---

## Phase 9: Convergence

**Purpose**: Support the clarified case where the first installment is a promotional payment that may be below ordinary accrued interest.

- [X] T049 [US2] Add an explicit promotional/introductory payment policy to the loan repayment domain and persistence, including deterministic treatment of waived, deferred/capitalized, or otherwise configured interest, so a promotional first payment is accepted without silently corrupting principal, interest, balances, or totals in `app/models/financial/loan.rb`, `app/models/financial/loans/repayment_terms.rb`, `app/models/financial/loans/amortization_schedule.rb`, and the applicable migration (user clarification: promotional first payment, FR-011, FR-018, contradicts; superseded by T052)
- [X] T050 [P] [US2] Add regression coverage for a promotional first payment of `50` followed by regular payments, asserting the selected interest policy, installment allocations, final balance, and total repayment in `test/models/financial/loans/repayment_terms_test.rb`, `test/models/financial/loans/amortization_schedule_test.rb`, and `test/services/financial/loans/repayment_workflows_test.rb` (US2/AC1, SC-006, missing; superseded by T052)
- [X] T051 [US2] Add clear loan-form and schedule-summary controls explaining that the first payment is promotional and showing whether its interest is waived, deferred/capitalized, or handled by the selected policy in `app/controllers/financial/loans_controller.rb`, `app/views/financial/loans/_form.html.erb`, `app/views/financial/loans/show.html.erb`, and `app/javascript/controllers/loan_terms_controller.js` (US2/AC1, FR-011, missing; superseded by T052)

---

## Phase 10: Convergence

**Purpose**: Preserve the existing under-interest validation while making the rule understandable before and after schedule generation.

- [X] T052 [US2] Supersede the promotional/waived/deferred behavior requested by T049–T051 with the clarified rule: do not add promotional-payment fields or alter accounting semantics; retain rejection when an installment cannot cover its accrued interest and implement only the UX remediation in T053–T055 (user clarification, FR-011, contradicts)
- [X] T053 [US2] Expose an authoritative minimum-payment calculation for each payment position and add server-side loan-form validation that explains when the configured beginning amount such as `1` or `50` is below the first installment’s accrued interest in `app/models/financial/loans/repayment_terms.rb`, `app/models/financial/loans/amortization_schedule.rb`, and `app/controllers/financial/loans_controller.rb` (US2/AC1, partial)
- [X] T054 [P] [US2] Add live form guidance that displays the calculated minimum valid payment for the selected principal, frequency, payment count, regular amount, different amount, and position, while keeping server-side validation authoritative, in `app/javascript/controllers/loan_terms_controller.js` and `app/views/financial/loans/_form.html.erb` (US2/AC1, SC-006, missing)
- [X] T055 [US2] Replace the generic schedule-generation alert with an actionable message naming the affected installment, accrued interest, entered payment, and minimum required payment, and preserve the user’s entered loan values after the failed generation in `app/models/financial/loans/amortization_schedule.rb`, `app/services/financial/loans/regenerate_schedule.rb`, `app/controllers/financial/loans/schedules_controller.rb`, and `app/views/financial/loans/show.html.erb` (US2/AC1, partial)
- [X] T056 [P] [US2] Add regression coverage proving invalid `1` and `50` beginning payments remain rejected with useful form/flash guidance while valid beginning payments still generate reconciled schedules in `test/models/financial/loans/repayment_terms_test.rb`, `test/models/financial/loans/amortization_schedule_test.rb`, and `test/controllers/financial/loans_controller_test.rb` (FR-011, SC-006, missing)

---

## Phase 11: Convergence

**Purpose**: Allow contractual due-date corrections after payment while preserving actual transaction history.

- [X] T057 [US3] Add a paid-installment due-date service regression proving `due_date` and `manual_due_date` can be corrected after payment application without changing the payment entry’s actual date, amount, interest, or accounting history in `test/services/financial/loans/update_installment_due_date_test.rb` (US3/AC3, FR-016, missing)
- [X] T058 [US3] Add a request/UI regression proving a paid installment still renders the due-date editor, accepts the PATCH action, updates the contractual due date, and returns a success notice while preserving the applied payment in `test/controllers/financial/loans_controller_test.rb` and the loan show view coverage (US3/AC3, SC-006, missing)
- [X] T059 [US3] Make the paid-row impact summary explicit in `app/views/financial/loans/show.html.erb`: identify the edited value as the contractual due date, state that the actual payment/application date and accounting history remain unchanged, and keep the installment editor enabled after payment (US3/AC3, FR-013, partial)
- [X] T060 [P] [US3] Add regression coverage proving that when a linked planned transaction has already been applied, correcting the paid installment due date does not mutate that planned/actual record or attempt a non-pending planned-date update, while eligible pending planned records remain independently consent-controlled in `test/services/financial/loans/update_installment_due_date_test.rb` (US3/AC3, SC-007, missing)

---

## Phase 12: Convergence

**Purpose**: Complete the due-date impact review, stale-state protection, and contractual date validation required by the feature artifacts.

- [X] T061 [US3] Add an explicit due-date impact-review step that summarizes the installment change, every eligible linked planned-record change, and protected actual-record history before save, with independent approve/decline choices and confirmation feedback in `app/views/financial/loans/show.html.erb`, `app/controllers/financial/loans/installments_controller.rb`, and `app/services/financial/loans/update_installment_due_date.rb` (FR-015, SC-007, partial)
- [X] T062 [US3] Add stale-state protection to the due-date form and workflow by submitting the installment version/updated timestamp, rejecting stale corrections with actionable feedback, and keeping the atomic selected update behavior in `app/views/financial/loans/show.html.erb`, `app/controllers/financial/loans/installments_controller.rb`, and `app/services/financial/loans/update_installment_due_date.rb` (US3/AC1, plan: stale-state rechecks, missing)
- [X] T063 [P] [US3] Enforce contractual due-date ordering rules at the installment/domain boundary, including invalid placement relative to neighboring contractual installments and paid-installment corrections that preserve actual dates, with focused regression coverage in `app/models/financial/loan/installment.rb`, `app/services/financial/loans/update_installment_due_date.rb`, `test/models/financial/loan/installment_test.rb`, and `test/services/financial/loans/update_installment_due_date_test.rb` (US3/AC1, FR-014, missing)

---

## Phase 13: Convergence

**Purpose**: Restore Constitution II domain ownership by moving regeneration business rules out of the service layer.

- [X] T064 [US2] Move substantive schedule-regeneration behavior from `Financial::Loans::RegenerateSchedule` into the owning `Financial::Loan`/`Financial::Loan::Installment` domain boundary or a clearly named namespaced regeneration domain object, including protected-extra checks, paid-installment policy, manual-date preservation/reset, installment reconciliation, and the atomic transaction; retain the service only as a thin Rails-facing adapter (Constitution II, FR-008, contradicts)
- [X] T065 [P] [US2] Add domain-boundary regression coverage proving regeneration rules execute correctly without service-owned business logic, while preserving the existing service/controller workflow contract and financial reconciliation in `test/models/financial/loan_test.rb`, `test/models/financial/loan/installment_test.rb`, `test/services/financial/loans/repayment_workflows_test.rb`, and `test/services/financial/loans/regenerate_schedule_test.rb` (Constitution II/IV, SC-006, partial)
