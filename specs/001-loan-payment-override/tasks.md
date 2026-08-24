---

description: "Implementation tasks for loan payment override position"
---

# Tasks: Loan Payment Override Position

**Input**: Design documents from `/specs/001-loan-payment-override/`

**Prerequisites**: `plan.md`, `spec.md`, `research.md`, `data-model.md`, `contracts/loan-simulation-ui.md`, and `quickstart.md`

**Scope note**: The current plan covers one fixed different-payment amount positioned at
the beginning or final payment. The extra-payment event and configurable interest-policy
requirements in `spec.md` (FR-011–FR-017) are not represented by the current plan or
existing domain model; they require a subsequent specification/plan slice before
implementation.

## Phase 1: Setup (Shared Infrastructure)

**Purpose**: Establish the implementation baseline in the existing Rails loan domain.

- [X] T001 Inspect the existing loan repayment, schedule regeneration, form, and test patterns in `app/models/financial/`, `app/services/financial/loans/`, `app/controllers/financial/loans_controller.rb`, `app/views/financial/loans/_form.html.erb`, and `test/` before changing the feature
- [X] T002 Confirm the focused verification commands from `specs/001-loan-payment-override/quickstart.md` run against the current test database and record any pre-existing failures

---

## Phase 2: Foundational (Blocking Prerequisites)

**Purpose**: Add the persisted repayment-term position and establish the neutral amount naming before story work.

**⚠️ CRITICAL**: User-story implementation depends on this phase.

- [X] T003 Create a reversible migration in `db/migrate/20260824000000_add_payment_position_and_rename_different_payment_amount.rb` that renames `financial_loans.final_payment_amount` to `different_payment_amount` and adds `different_payment_position` with a `final` default, preserving existing decimal values
- [X] T004 [P] Add the `different_payment_position` and `different_payment_amount` schema names to `db/schema.rb` by running the migration and verify existing rows retain final-payment semantics
- [X] T005 [P] Add focused migration/compatibility coverage in `test/models/financial/loan_test.rb` for the default `final` position and unchanged existing different-payment amount

**Checkpoint**: The database and model-facing names can represent both beginning and final positions without changing existing financial values.

---

## Phase 3: User Story 1 - Choose the Position of a Different Payment (Priority: P1) 🎯 MVP

**Goal**: Let a loan simulation configure one exceptional payment as either the first or final contractual payment while preserving final-payment compatibility.

**Independent Test**: Build payment-amount terms with a different amount and each position, then verify the ordered contractual payment stream; submit the loan form and verify the persisted position and amount.

### Tests for User Story 1

- [X] T006 [P] [US1] Add `beginning` and `final` contractual-payment stream tests, default-position coverage, one-payment coverage, invalid-position coverage, and positive-amount validation in `test/models/financial/loans/repayment_terms_test.rb`
- [X] T007 [P] [US1] Add loan configuration and repayment-term mapping tests for `different_payment_position` and `different_payment_amount` in `test/models/financial/loan_test.rb`
- [X] T008 [P] [US1] Add request tests for creating and updating a payment-amount simulation with `different_payment_position` in `test/controllers/financial/loans_controller_test.rb`

### Implementation for User Story 1

- [X] T009 Update `app/models/financial/loans/repayment_terms.rb` to accept `different_payment_position`, expose `different_payment_amount`, default the position to `final`, validate only `beginning` and `final`, and place the exceptional amount exactly once in `contractual_payments`
- [X] T010 Update `app/models/financial/loan.rb` to validate and persist `different_payment_position`, configure terms with `different_payment_amount`, and map persisted repayment terms without rewriting monetary values
- [X] T011 Update `app/controllers/financial/loans_controller.rb` to permit `different_payment_position` and `different_payment_amount`, pass both into `RepaymentTerms`, preserve the final default for omitted legacy input, and include the new fields when detecting repayment changes
- [X] T012 Update `app/views/financial/loans/_form.html.erb` to replace the final-only amount field with a neutral different-payment field and add an accessible Beginning/Final `different_payment_position` selector using the existing UI components
- [X] T013 Update `app/javascript/controllers/loan_terms_controller.js` to read the selected `different_payment_position` and construct the estimate payment array with the exceptional amount at the selected position, including the one-payment case

**Checkpoint**: A user can create or edit a simulation with either position, and existing omitted-position records continue to mean final payment.

---

## Phase 4: User Story 2 - Review an Accurate Schedule (Priority: P1)

**Goal**: Generate and display a reconciled schedule whose exceptional payment appears at the selected position and whose totals remain financially valid.

**Independent Test**: Generate schedules for beginning and final overrides, then verify installment order, amounts, principal closure, interest totals, and actionable rejection of unreconciled inputs.

### Tests for User Story 2

- [X] T014 [P] [US2] Add beginning-position, final-position, one-payment, rounding, invalid-overpayment, and paid-prefix schedule coverage in `test/models/financial/loans/amortization_schedule_test.rb`
- [X] T015 [P] [US2] Add schedule-regeneration coverage proving changing the position regenerates only the permitted unpaid projections and preserves protected paid/planned installments in `test/services/financial/loans/repayment_workflows_test.rb`
- [X] T016 [P] [US2] Add request coverage for generated schedule amounts and validation feedback in `test/controllers/financial/loans_controller_test.rb`
- [X] T017 [P] [US2] Add or update a component/system boundary test for the position label and exceptional-payment identification in `test/components/` or `test/system/` using the existing loan UI test conventions

### Implementation for User Story 2

- [X] T018 Update `app/models/financial/loans/amortization_schedule.rb` to consume the ordered contractual payment stream, keep the selected exceptional amount aligned after paid-prefix handling, prevent negative balances, and retain precise monetary reconciliation
- [X] T019 Update `app/services/financial/loans/regenerate_schedule.rb` only where needed to pass the updated repayment terms while preserving its existing loan lock, transaction, and paid/planned-installment safeguards
- [X] T020 Update `app/views/financial/loans/show.html.erb` and the relevant installment/schedule component or partial to identify the exceptional payment position and expose reconciled totals or validation feedback clearly
- [X] T021 Verify `app/controllers/financial/loans_controller.rb` schedule creation and regeneration responses render actionable domain validation errors without persisting an inaccurate schedule

**Checkpoint**: Beginning and final overrides produce independently reviewable, reconciled schedules, and invalid schedules are rejected visibly.

---

## Phase 5: Polish & Cross-Cutting Concerns

**Purpose**: Verify compatibility, accessibility, documentation alignment, and repository quality gates.

- [X] T022 [P] Update `specs/001-loan-payment-override/data-model.md`, `specs/001-loan-payment-override/contracts/loan-simulation-ui.md`, and `specs/001-loan-payment-override/quickstart.md` if implementation names or verification commands differ from the generated behavior
- [X] T023 [P] Run the focused Rails model, controller, and workflow tests from `specs/001-loan-payment-override/quickstart.md` and resolve regressions in the changed loan behavior
- [X] T024 [P] Run Herb lint against the modified loan ERB files and fix accessibility or template issues; record unrelated repository-wide lint failures separately
- [X] T025 Run the relevant request/UI boundary checks and inspect the loan form markup for keyboard access, clear labels, readable contrast, and correct Beginning/Final estimate text
- [X] T026 Review `spec.md` FR-011–FR-017 against the delivered implementation, document them as deferred follow-up work in the feature notes, and do not claim those extra-payment/interest-policy behaviors are implemented

---

## Dependencies & Execution Order

### Phase Dependencies

- **Setup (Phase 1)**: No implementation dependency; establishes the baseline.
- **Foundational (Phase 2)**: Depends on Setup and blocks user stories because the domain and schema names must be settled first.
- **User Stories (Phases 3–4)**: Depend on Phase 2. US2 uses the terms contract completed by US1, so implement US1 before US2 for this single-developer slice.
- **Polish (Phase 5)**: Depends on the desired user stories being complete.

### User Story Dependencies

- **US1 (P1)**: Depends on Phase 2; provides the persisted position and ordered contractual payment stream.
- **US2 (P1)**: Depends on US1's terms API, but remains independently testable through schedule generation and regeneration.

### Within Each User Story

- Write focused tests before implementation and confirm the expected failure.
- Complete the domain terms/model work before controller and UI integration.
- Complete schedule behavior before schedule presentation and end-to-end verification.

### Parallel Opportunities

- T006–T008 can be prepared in parallel after the schema/API shape is agreed.
- T014–T017 can be prepared in parallel because they cover separate test boundaries.
- T022–T024 can run in parallel after implementation.

## Parallel Example: User Story 1

```text
Task T006: RepaymentTerms domain tests in test/models/financial/loans/repayment_terms_test.rb
Task T007: Financial::Loan mapping tests in test/models/financial/loan_test.rb
Task T008: Loan controller request tests in test/controllers/financial/loans_controller_test.rb
```

## Parallel Example: User Story 2

```text
Task T014: AmortizationSchedule tests in test/models/financial/loans/amortization_schedule_test.rb
Task T015: Regeneration workflow tests in test/services/financial/loans/repayment_workflows_test.rb
Task T017: User-visible schedule/position test in test/components/ or test/system/
```

## Implementation Strategy

### MVP First

1. Complete Phase 1 baseline checks.
2. Complete Phase 2 schema and compatibility work.
3. Complete Phase 3 (US1) and validate beginning/final contractual payment ordering.
4. Stop and validate the simulation form and persisted terms independently.

### Incremental Delivery

1. Add US1 domain and form behavior.
2. Add US2 schedule generation, regeneration, and presentation behavior.
3. Run focused tests, Herb lint, and UI verification.
4. Track FR-011–FR-017 as a separate follow-up feature requiring its own plan.

## Notes

- Every task uses the required `- [ ] T###` checklist format and names at least one concrete file path.
- `[P]` marks tasks that can be worked on concurrently without modifying the same primary file.
- No new repository, interactor, or generic service layer is required by the current plan.
