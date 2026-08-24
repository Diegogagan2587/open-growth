# Feature Specification: Loan Installment Domain and Schedule Management

**Feature Branch**: `002-loan-installment-namespace`

**Created**: 2026-08-24

**Status**: Draft

**Input**: User description: "Rename and move the loan installment model into its corresponding `Financial::Loan::Installment` namespace so the model is less redundant and follows Rails conventions." This specification also incorporates the previously clarified loan-payment and installment-date requirements that were being tracked in feature `001`.

## Transferred Clarifications

The following decisions are part of this active specification and must not be lost when
the model is renamed:

### Session 2026-08-23

- The exceptional payment is one configured amount, positioned at either the beginning or
  final payment; the neutral names are `different_payment_amount` and
  `different_payment_position`, with existing records defaulting to `final`.
- The schedule must remain financially reconciled when the exceptional payment is moved;
  a one-payment loan applies it once, and paid-prefix handling remains safe.
- The repayment schedule is anchored by `first_payment_date`, meaning the first payment's
  contractual due date, not the date the loan funds were received or disbursed.
- Extra-payment and interest-policy behavior remains explicitly specified for follow-up
  implementation rather than being silently discarded.

### Session 2026-08-24

- Editing one installment changes only that installment; neighboring dates do not shift.
- Contractual due dates are distinct from actual payment/application dates. A paid
  installment's due date may be corrected, while payment dates, amounts, interest, and
  accounting history remain unchanged.
- One impact summary lists every affected linked record, with an independent choice for
  each planned-record update; there is no popup cascade.
- Ordinary schedule regeneration preserves manually edited dates. An explicit reset lists
  each affected manual date and permits accepting or rejecting each replacement.
- Linked planned records are updated only after explicit confirmation. Their due-date fields
  may change, but an actual transaction's recorded/application date must not change.
- Stale linked-record state must be rechecked before applying a confirmed update; a stale
  confirmation produces no partial linked update.

## User Scenarios & Testing *(mandatory)*

### User Story 1 - Use a Clear Loan-Owned Installment Model (Priority: P1)

As a developer maintaining the loan domain, I want the installment model to be named
`Financial::Loan::Installment` and located under the loan namespace so its ownership is
obvious and the redundant top-level name is removed.

**Why this priority**: Clear domain ownership reduces confusion when reading loan models,
services, controllers, and tests, especially as the application gains other installment-
like concepts.

**Independent Test**: Load the application and assert that `Financial::Loan::Installment`
exists, maps to the existing loan-installment table, and replaces the old constant in the
loan association and focused domain tests.

**Acceptance Scenarios**:

1. **Given** the application code, **when** a developer references the loan installment
   model, **then** the canonical constant is `Financial::Loan::Installment`.
2. **Given** the existing persisted loan-installment records, **when** the renamed model
   loads them, **then** it reads and writes the same records without changing table,
   column, association, or financial data semantics.
3. **Given** an application boot, **when** Rails autoloads the model, **then** the file
   path and constant namespace agree and no obsolete model constant is required.

---

### User Story 2 - Configure an Accurate Payment Schedule (Priority: P1)

As a loan user, I want the exceptional payment position and first payment date to be
explicit so the generated schedule reflects the contract I entered.

**Independent Test**: Generate beginning and final exceptional-payment schedules, including
a one-payment loan, with a first payment date later than the loan receipt date.

**Acceptance Scenarios**:

1. **Given** a different payment amount, **when** the user chooses Beginning or Final,
   **then** that amount appears exactly once in the selected contractual position and the
   schedule remains reconciled.
2. **Given** a monthly loan first due on September 15, **when** the schedule is generated,
   **then** installment one is due September 15 and later dates follow the frequency.
3. **Given** an existing schedule, **when** the loan is opened without regeneration,
   **then** its installment dates remain unchanged.

---

### User Story 3 - Correct Due Dates with Explicit Impact Choices (Priority: P1)

As a loan user, I want to correct installment due dates from the loan view while knowing
exactly which planned records could change and which actual records are protected.

**Independent Test**: Edit an unpaid installment, one linked to a pending planned
transaction, and one with an actual payment; exercise approve, decline, cancel, stale, and
selective-reset paths.

**Acceptance Scenarios**:

1. **Given** an installment, **when** its due date changes, **then** only that installment
   changes unless the user explicitly selects other reset changes.
2. **Given** a linked pending planned transaction, **when** the impact summary is shown,
   **then** its due-date update is independently selectable and only confirmed fields are
   synchronized.
3. **Given** a completed payment, **when** its contractual due date changes, **then** the
   actual payment/application date and historical financial values remain unchanged.
4. **Given** a reset affecting manual dates, **when** the summary is shown, **then** each
   proposed reset is independently accepted or rejected.
5. **Given** cancellation or stale linked state, **then** no partial linked update occurs
   and the user receives actionable feedback.

---

### User Story 4 - Preserve Loan Workflows During the Rename (Priority: P1)

As a user of loan scheduling and payment workflows, I want the namespace cleanup to be
behavior-preserving so schedule generation, planning, payment application, reporting, and
loan-view behavior continue to work exactly as before.

**Why this priority**: This is a domain refactor, not a financial behavior change; users
must not experience altered balances, dates, amounts, or payment state transitions.

**Independent Test**: Run the existing loan model, schedule, controller, service, and
component tests after the rename and verify that generated installments, planned links,
actual payment links, and financial totals remain unchanged.

**Acceptance Scenarios**:

1. **Given** a loan with generated installments, **when** its schedule is regenerated,
   **then** the same installment rows, amounts, dates, and resolutions are produced.
2. **Given** an installment linked to a planned transaction, **when** the installment is
   planned or the pending plan is synchronized, **then** the same link and planned values
   are maintained.
3. **Given** an installment with an actual payment, **when** the payment workflow runs,
   **then** the same payment and interest entries are associated and no accounting values
   change.
4. **Given** code that queries or renders loan installments, **when** the refactor is
   complete, **then** every supported caller uses the new namespaced model without a
   compatibility alias being required at runtime.

### Edge Cases

- Existing records in `financial_loan_installments` remain readable after application
  restart and schema loading.
- Associations with foreign keys and inverse relationships continue to resolve through
  the new model constant.
- Namespaced subclasses, domain objects, or services with similar installment names do
  not become ambiguous with the renamed model.
- Tests and autoloading must not pass only because the obsolete constant remains as an
  undocumented alias.
- The refactor must not rename the database table, columns, indexes, or foreign keys.
- A failed rename must leave the working tree without two competing canonical model
  classes.

## Requirements *(mandatory)*

### Functional Requirements

- **FR-001**: The system MUST define the loan installment model as
  `Financial::Loan::Installment`.
- **FR-002**: The model file MUST follow the namespace path
  `app/models/financial/loan/installment.rb`.
- **FR-003**: The system MUST continue to use the existing
  `financial_loan_installments` table and all existing persisted columns, indexes, and
  foreign keys.
- **FR-004**: The system MUST update the `Financial::Loan` association and all loan
  workflow references to use `Financial::Loan::Installment`.
- **FR-005**: The system MUST update focused model, service, controller, component, and
  integration tests to use the canonical namespaced constant and matching test path.
- **FR-006**: The system MUST not introduce a second competing installment model or rely
  on an undocumented compatibility alias for normal application execution.
- **FR-007**: The system MUST preserve existing installment associations to planned
  transactions, payment entries, interest entries, and loans.
- **FR-008**: The system MUST preserve all existing financial behavior, including schedule
  generation, regeneration, payment application, totals, resolutions, and account
  ownership checks.
- **FR-009**: The system MUST not require a data migration solely because the Ruby model
  constant and file path changed.
- **FR-010**: The system MUST pass application boot/autoload verification and the relevant
  loan test suite after the refactor.
- **FR-011**: The system MUST persist and expose `different_payment_amount` and
  `different_payment_position`, with `beginning` and `final` as the only positions and
  `final` as the compatibility default.
- **FR-012**: The system MUST use `first_payment_date` as the first contractual due-date
  anchor and clearly distinguish it from loan receipt/disbursement date.
- **FR-013**: The system MUST distinguish contractual due dates, planned-record due dates,
  and actual payment/application dates.
- **FR-014**: The system MUST treat a directly edited installment date as a manual
  exception and leave neighboring installments unchanged.
- **FR-015**: The system MUST show one impact summary with independent choices for every
  linked planned-record update and every manually edited date affected by reset.
- **FR-016**: The system MUST preserve actual transaction dates, amounts, interest, and
  accounting history when installment due dates change.
- **FR-017**: Ordinary regeneration MUST preserve manual due dates; selective reset MUST
  permit per-installment approval or rejection.
- **FR-018**: Extra-payment events and configurable interest-allocation policies MUST remain
  represented in the domain specification and be tracked as an explicitly planned slice,
  not omitted or implied to be implemented by the namespace rename.

### Key Entities

- **Financial loan**: The owning domain entity with a one-to-many relationship to loan
  installments.
- **Financial loan installment**: A persisted scheduled repayment row represented by the
  canonical `Financial::Loan::Installment` model.
- **Planned transaction**: An optional future transaction linked to an installment.
- **Payment and interest entries**: Actual financial records linked to an installment and
  preserved by the rename.

## Success Criteria *(mandatory)*

### Measurable Outcomes

- **SC-001**: 100% of supported loan installment callers use
  `Financial::Loan::Installment` after the refactor.
- **SC-002**: Application boot and autoload checks complete without missing-constant or
  duplicate-constant errors.
- **SC-003**: The relevant loan test suite passes with no changes to expected financial
  amounts, dates, resolutions, links, or totals.
- **SC-004**: Existing rows in `financial_loan_installments` remain readable and writable
  without a table or data migration.
- **SC-005**: A code reviewer can identify the installment model’s loan ownership from
  its constant and file path without consulting additional documentation.
- **SC-006**: The focused loan schedule and date-impact tests verify payment ordering,
  first-payment anchoring, manual-date preservation, planned-record consent, and actual
  transaction-date preservation without changing financial totals.
- **SC-007**: No supported workflow silently changes a linked planned or actual record;
  every affected planned update is explicitly accepted or declined in one summary.

## Assumptions

- The canonical Rails model name is the singular `Financial::Loan::Installment`; Rails
  conventions keep the database table plural as `financial_loan_installments`.
- The namespace refactor itself is behavior-preserving, while the transferred schedule
  requirements define the behavior that the surrounding loan feature must implement.
- Existing database schema and records are authoritative and must remain unchanged.
- Existing authorization and account-scoping behavior remains in force.
- The refactor can update all in-repository callers in one focused change.
