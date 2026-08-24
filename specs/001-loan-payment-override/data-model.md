# Data Model: Loan Payment Override Position

## Financial::Loan

Existing entity representing a loan simulation or active loan.

### New attribute

| Attribute | Type | Required | Rules | Compatibility |
|---|---|---:|---|---|
| `different_payment_position` | string | No for annual-rate loans; defaults to `final` | Allowed values: `beginning`, `final`; meaningful when `different_payment_amount` is present | Existing rows and existing final-payment inputs resolve to `final` |

The existing `final_payment_amount` data becomes `different_payment_amount` in the
domain. Its stored values remain unchanged; only the name and interpretation become
position-neutral, while the UI explains the selected `different_payment_position`.

### Domain behavior

- `repayment_terms` passes `different_payment_position` and `different_payment_amount` into
  `RepaymentTerms`.
- Payment-amount terms produce an ordered contractual stream from regular payment plus
  the optional different payment and position.
- Annual-rate terms continue to derive the regular payment and do not require a
  different-payment amount; the position may retain its default without affecting the
  annual-rate calculation.
- A one-payment loan uses the different amount once, regardless of position.

## Financial::Loans::RepaymentTerms

Immutable value object for validated repayment inputs.

### New value

`different_payment_position` is accepted as `beginning` or `final`, defaulting to `final` for
compatibility. Invalid values raise the same domain-level argument error style used by
existing repayment validation.

### Invariants

- Principal is positive.
- Number of payments is positive.
- Regular and different payment amounts, when supplied for payment-amount terms, are
  positive.
- The ordered contractual payment total is not less than principal.
- The different amount occurs exactly once when supplied.

## Financial::Loans::AmortizationSchedule

Existing projection generator. It consumes the ordered contractual payment stream and
continues to produce installment number, due date, amount, principal, and interest.
The first or last exceptional amount must remain aligned with the corresponding
installment number after paid-prefix handling.

## Financial::LoanInstallment

Existing persisted projection entity. No new fields are required. Regeneration must
continue to protect paid and planned installments and synchronize pending plans within
the existing atomic workflow.

## State and migration notes

- Migration adds `different_payment_position` with a database default of `final`.
- Migration renames `final_payment_amount` to `different_payment_amount`, or provides
  an explicit compatibility mapping if the project chooses to retain the old column.
- Existing rows require no amount rewrite and retain their current schedule meaning.
- The migration must be reversible by removing the new column; rollback is safe because
  the new column does not replace existing financial amounts.
- If the project uses a database-level check constraint for allowed values, it must
  accept both `beginning` and `final` and remain compatible with the default.
