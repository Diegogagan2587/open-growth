# Feature Specification: Loan Payment Override Position

**Feature Branch**: `001-loan-payment-override`

**Created**: 2026-08-23

**Status**: Draft

**Input**: User description: "On loans, when simulating a loan, the option to change a different payment is treated as the final payment. A loan may instead have a different payment at the beginning, so allow a different payment at either the beginning or final payment."

## Clarifications

### Session 2026-08-23

- Q: Should the loan support only one configured different payment, or should users be able to make extra payments repeatedly and recalculate the remaining schedule? → A: Support both fixed beginning/final payment overrides and repeated extra-payment events.
- Q: After an extra payment reduces the outstanding principal, should the loan keep the same regular payment and finish earlier, recalculate a lower regular payment over the original remaining term, or let the user choose? → A: Keep the same regular payment and finish earlier.
- Q: How should the user specify whether early payments reduce interest? → A: Each loan explicitly specifies its interest policy.
- Q: For a fixed-total-interest loan, when the user makes an extra payment, should the extra amount reduce only the principal while the remaining contracted interest stays distributed across the remaining payments? → A: Reduce principal, preserve total interest, keep regular payments, and adjust the final payment or remaining term as needed.

## User Scenarios & Testing *(mandatory)*

### User Story 1 - Choose the Position of a Different Payment (Priority: P1)

When simulating a loan, a user can identify whether the exceptional payment belongs
at the beginning or the end of the repayment schedule. This lets the simulation match
loan offers whose first payment differs from the regular payments as well as offers
whose final payment differs.

**Why this priority**: The current behavior assumes every different payment is the
final payment, which produces an incorrect repayment schedule for loans with a
different first payment.

**Independent Test**: Create a loan simulation with a different payment and select
the beginning position, then verify the first scheduled payment uses that amount and
the remaining schedule uses the regular payment rules.

**Acceptance Scenarios**:

1. **Given** a loan simulation with a regular payment and a different payment,
   **When** the user selects "Beginning", **Then** the first scheduled payment uses
   the different amount and later payments use the regular amount unless the remaining
   balance requires a final adjustment.
2. **Given** a loan simulation with a regular payment and a different payment,
   **When** the user selects "Final", **Then** the final scheduled payment uses the
   different amount, preserving the existing final-payment behavior.
3. **Given** a loan simulation without a different payment, **When** the user reviews
   the schedule, **Then** the schedule uses the regular payment rules without applying
   a beginning or final override.

---

### User Story 2 - Review an Accurate Schedule (Priority: P1)

After choosing the position of the different payment, the user can review the full
schedule and understand which payment is exceptional, how many payments are required,
and whether the total repayment covers the simulated loan balance.

**Why this priority**: A payment-position choice is useful only if the resulting
schedule and totals remain financially accurate.

**Independent Test**: Generate schedules with beginning and final overrides and compare
the displayed payment order, payment count, outstanding balance, and total repayment
against the selected inputs.

**Acceptance Scenarios**:

1. **Given** a beginning override, **When** the schedule is generated, **Then** the
   exceptional amount appears in the first payment position and is clearly identified.
2. **Given** a final override, **When** the schedule is generated, **Then** the
   exceptional amount appears in the final payment position and is clearly identified.
3. **Given** an override that would cause the schedule to underpay or overpay the
   simulated balance, **When** the schedule is generated, **Then** the user receives a
   clear validation result and the application does not silently present an inaccurate
   schedule.

### Edge Cases

- A beginning or final different payment is equal to the regular payment; the schedule
  remains valid and contains no contradictory position information.
- The different payment is zero, negative, or otherwise invalid; the user receives a
  validation message and cannot generate an invalid schedule.
- The different payment is greater than the simulated balance; the schedule must not
  create a negative outstanding balance or hide an overpayment.
- The loan has only one payment; beginning and final positions refer to the same
  payment, and the schedule must not apply the override twice.
- Rounding or precise monetary calculations leave a remainder; the schedule must
  disclose and resolve it without floating-point financial behavior.
- An existing loan created under the final-payment behavior is viewed or regenerated;
  its existing meaning and payment position remain unchanged unless the user edits it.
- A user makes multiple extra payments over the life of a loan; each extra payment is
  applied once and the remaining schedule reflects the cumulative principal reduction.
- The loan charges a fixed total interest amount that does not decrease after early
  repayment; the schedule must not claim interest savings unless the loan's terms allow
  interest to be recalculated.

## Requirements *(mandatory)*

### Functional Requirements

- **FR-001**: The system MUST allow a user simulating a loan to specify whether a
  different payment amount is applied at the beginning or at the final payment
  position through a `payment_position` choice.
- **FR-002**: The system MUST preserve the existing final-payment behavior when the
  user selects the final position.
- **FR-003**: The system MUST place a beginning-position different payment first and
  a final-position different payment last in the generated schedule.
- **FR-004**: The system MUST apply the regular payment rules to all non-exceptional
  payment positions, subject to the balance and schedule constraints.
- **FR-005**: The system MUST calculate payment count, outstanding balance, and total
  repayment using precise monetary values and MUST prevent silently inaccurate totals.
- **FR-006**: The system MUST validate that the different payment is a valid positive
  monetary amount before generating the schedule.
- **FR-007**: The system MUST handle a one-payment loan without applying a beginning or
  final override more than once.
- **FR-008**: The system MUST preserve the position and financial meaning of existing
  loans that were created with the prior final-payment behavior.
- **FR-009**: The user-facing simulation form and resulting schedule MUST clearly label
  the selected position and identify the exceptional payment.
- **FR-010**: The system MUST provide actionable feedback when the selected override
  cannot produce a financially valid schedule.
- **FR-011**: The system MUST support optional extra-payment events in addition to a
  single fixed beginning or final payment override.
- **FR-012**: The system MUST apply each recorded extra-payment event once and include
  its effect in the remaining principal and future interest calculation.
- **FR-013**: After an extra-payment event, the system MUST preserve the regular payment
  amount and reduce the remaining number of payments or final payment as needed to
  close the loan earlier.
- **FR-014**: The system MUST calculate interest according to the loan's configured
  interest policy; early payment MUST reduce future interest only when that policy
  recalculates interest from the reduced principal.
- **FR-015**: The system MUST distinguish loans where early payment reduces future
  interest from loans where the total interest is fixed or otherwise unchanged.
- **FR-016**: The system MUST allow each loan to specify an interest policy that is
  either principal-reducing or fixed-total-interest.
- **FR-017**: For fixed-total-interest loans, an extra payment MUST reduce outstanding
  principal while preserving the contracted total interest, and the system MUST NOT
  report interest savings from that payment.

### Key Entities *(include if feature involves data)*

- **Loan simulation**: The user's proposed borrowing terms, including regular payment,
  optional different payment, payment count, frequency, and repayment position.
- **Payment terms**: The loan's regular payment, optional different payment amount,
  and `payment_position` that determines where the different amount is placed.
- **Extra-payment event**: A user-recorded payment above the scheduled amount, with an
  amount and date, that reduces the outstanding principal and affects later repayment.
- **Interest policy**: The loan rule that determines whether early principal repayment
  reduces future interest or leaves the contracted interest amount unchanged.
- **Repayment schedule**: The ordered set of projected payments, amounts, dates, and
  remaining balance produced from the simulation.

## Success Criteria *(mandatory)*

### Measurable Outcomes

- **SC-001**: Users can create a simulation with a beginning different payment and
  verify its first scheduled payment in under 2 minutes.
- **SC-002**: 100% of valid simulations with a beginning override place the different
  payment first, and 100% with a final override place it last.
- **SC-003**: 100% of generated schedules reconcile their displayed totals and remaining
  balance to the selected loan terms without silent overpayment or underpayment.
- **SC-004**: 100% of invalid override amounts receive a clear validation result and do
  not produce an accepted inaccurate schedule.
- **SC-005**: Existing final-position loan simulations retain their prior schedule and
  financial meaning when opened after the change.
- **SC-006**: Users can record more than one extra-payment event, and the schedule
  reflects the cumulative principal reduction without duplicating any event.
- **SC-007**: For loans whose interest policy recalculates from principal, the schedule
  reflects lower future interest after an extra payment; for fixed-interest loans, it
  preserves the contracted interest total.

## Assumptions

- The feature applies to loan simulation and schedule generation; changing the
  underlying loan product, interest model, or payment frequency is out of scope.
- A simulation has at most one different payment amount and one `payment_position`,
  which is either beginning or final; supporting both positions simultaneously is out
  of scope unless a later requirement adds it.
- The regular payment remains the default for all other scheduled payments.
- Existing loans without an explicitly stored position continue to be interpreted as
  final-payment overrides for backward compatibility.
- The existing loan repayment rules determine how a remainder is handled when the
  selected amounts do not divide evenly into the balance.
- Extra-payment events are optional and are separate from the fixed beginning/final
  different-payment setting; both mechanisms may be used for the same loan.
- The loan's interest policy is either already available in the product or must be
  selected when the loan is configured; the feature must not infer interest savings from
  early payment alone.
