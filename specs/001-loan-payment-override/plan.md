# Implementation Plan: Loan Payment Override Position

**Branch**: `001-loan-payment-override` | **Date**: 2026-08-23 | **Spec**: [spec.md](./spec.md)

**Input**: Feature specification from `/specs/001-loan-payment-override/spec.md`

## Summary

Add an explicit `payment_position` choice for the optional different payment in the
financial loan repayment terms. Model the exceptional value as a neutral
`different_payment_amount`, while migrating the existing `final_payment_amount` value
without changing its meaning. Preserve existing records as final-payment overrides,
generate contractual payment arrays with the override in the selected position, and
update the loan form and estimate hint so the position is visible and accurate.

The change belongs in the existing `Financial::Loan` repayment domain and its
`Financial::Loans::RepaymentTerms` and `AmortizationSchedule` collaborators. It needs a
backward-compatible persisted position value, domain validation, atomic schedule
regeneration behavior, and focused model/domain/request coverage.

## Technical Context

**Language/Version**: Ruby 3.x / Rails 8.1

**Primary Dependencies**: Active Record, ViewComponent, Tailwind, Hotwire, Stimulus,
existing financial loan domain objects

**Storage**: PostgreSQL; `financial_loans` stores repayment configuration and
`financial_loan_installments` stores generated projections

**Testing**: Rails tests with existing Active Record fixtures where suitable; model,
domain-object, request/controller, component, and system tests at the appropriate
boundary

**Target Platform**: Authenticated Rails web application

**Project Type**: Rails web application

**Performance Goals**: A normal loan schedule simulation or regeneration completes
within the existing request interaction expectations and does not add a remote call.

**Constraints**: Preserve exact financial meaning; use precise decimal values for
persisted calculations; preserve existing final-payment records; prevent invalid or
unreconciled schedules; keep UI behavior accessible and component-consistent.

**Scale/Scope**: One optional different-payment amount per financial loan, positioned
by `payment_position` at the beginning or final payment; no simultaneous overrides.

## Constitution Check

*GATE: Must pass before Phase 0 research. Re-check after Phase 1 design.*

- **Financial correctness**: PASS. The position is represented as domain repayment
  data, payment ordering is tested, and schedule totals/balances remain reconciled.
- **Atomic state transitions**: PASS. Existing schedule regeneration transaction and
  lock remain the boundary for installment replacement and pending-plan synchronization.
- **Rich Rails-native domain model**: PASS. Terms and schedule behavior stay in the
  existing domain objects; no new generic service or repository layer is proposed.
- **Resource-oriented controllers**: PASS. The controller only permits and assigns the
  new input; validation and payment ordering remain outside the controller.
- **Boundary-focused testing**: PASS. Terms and schedule rules receive focused tests;
  form/request behavior receives boundary coverage; no mandatory AAA comments are added.
- **Component UI and accessibility**: PASS. The existing loan form and established
  select/input components are reused, with a clear label and accessible position choice.
- **Evolutionary Rails design**: PASS. The design extends current repayment terms and
  uses one small schema field; no speculative abstraction is introduced.
- **Data safety and migrations**: PASS. The new position defaults existing rows to
  `final`, and the existing amount is renamed or compatibility-mapped without
  rewriting financial values.

No constitution violations require complexity tracking.

## Project Structure

### Documentation (this feature)

```text
specs/001-loan-payment-override/
├── plan.md
├── research.md
├── data-model.md
├── quickstart.md
├── contracts/
│   └── loan-simulation-ui.md
└── tasks.md                 # created by $speckit-tasks
```

### Source Code (repository root)

```text
app/
├── models/financial/loan.rb
├── models/financial/loans/repayment_terms.rb
├── models/financial/loans/amortization_schedule.rb
├── controllers/financial/loans_controller.rb
├── views/financial/loans/_form.html.erb
└── javascript/controllers/loan_terms_controller.js
db/migrate/
└── <timestamp>_add_payment_position_and_rename_different_payment_amount.rb
test/
├── models/financial/loans/repayment_terms_test.rb
├── models/financial/loans/amortization_schedule_test.rb
├── models/financial/loan_test.rb
├── controllers/financial/loans_controller_test.rb
└── components/...
```

**Structure Decision**: Extend the existing Rails financial-loan domain and its current
simulation form. The `payment_position` value is persisted with the loan's repayment
terms; generated installments continue to be derived projections rather than a second
source of terms.

## Complexity Tracking

No violations.
