# Research: Loan Payment Override Position

## Decision 1: Persist an explicit payment position with a compatibility default

**Decision**: Add a constrained string value representing `beginning` or `final` to
the financial loan repayment configuration. Existing rows default to `final`.

**Rationale**: The current persisted field is `final_payment_amount`, and the existing
behavior treats it as the final payment. An explicit position removes the ambiguity
without changing existing loan meaning. A database default and model validation make
the compatibility rule visible and testable.

**Alternatives considered**:

- Infer position from which field is populated: rejected because one amount cannot
  express the user's choice and old data remains ambiguous.
- Add separate beginning and final amount fields: rejected because the feature scope
  allows one override and two fields would permit unsupported simultaneous overrides.
- Store position only in the form: rejected because regeneration and later editing
  must preserve the selected financial meaning.

## Decision 2: Build the contractual payment stream before schedule projection

**Decision**: `RepaymentTerms#contractual_payments` will place the optional different
payment at index zero for `beginning`, at the last index for `final`, and use the regular
payment elsewhere. A one-payment schedule applies the override once.

**Rationale**: The payment stream is the domain representation consumed by rate
inference and schedule generation. Centralizing ordering there avoids separate form,
controller, and schedule implementations.

**Alternatives considered**:

- Reorder amounts only in the controller: rejected because non-HTTP callers and
  schedule regeneration would not share the same financial rule.
- Special-case only `AmortizationSchedule`: rejected because annual-rate inference and
  simulation estimates also need the same ordered stream.

## Decision 3: Preserve the existing schedule regeneration boundary

**Decision**: Keep the existing loan lock and transaction in `RegenerateSchedule`.
Changing the position is treated like changing other repayment terms: existing unpaid
projections are reconciled, while paid or protected installments remain protected by
existing rules.

**Rationale**: This reuses the current atomic behavior and avoids introducing a second
workflow for a small repayment-term change.

**Alternatives considered**:

- Rewrite paid installments when position changes: rejected because it could alter
  recorded financial history.
- Add a new schedule mutation service: rejected because the existing domain operation
  already owns regeneration and its consistency boundary.

## Decision 4: Keep the UI choice in the existing loan form

**Decision**: Add an accessible position selector next to the different-payment input,
reuse established project select/input components, and update the Stimulus estimate to
use the selected ordered amounts.

**Rationale**: This is one repayment-term attribute, not a separate resource or workflow.
The existing form is the canonical simulation interface.

**Alternatives considered**:

- Add a separate payment-adjustment resource: rejected because one persisted term choice
  does not justify a new resource and would obscure the loan model.
- Add a second form for beginning payments: rejected because it duplicates the same
  repayment concept and increases UI drift.

## Decision 5: Validate positive overrides and financial reconciliation in the domain

**Decision**: Continue domain validation for positive monetary values and insufficient
payment totals, and add coverage for position validity, one-payment schedules, and
invalid combinations. UI hints are informative; server-side domain validation remains
authoritative.

**Rationale**: Financial correctness cannot depend on browser behavior or JavaScript.

**Alternatives considered**:

- Browser-only numeric validation: rejected because requests can bypass the browser and
  schedule generation has non-UI callers.
