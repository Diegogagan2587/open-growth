# Data Model: Loan Installment Domain and Schedule Management

## Financial::Loan

Existing loan entity. Repayment configuration includes:

| Attribute | Rule |
|---|---|
| `different_payment_amount` | Optional positive exceptional amount; renamed from the final-only concept without changing values |
| `different_payment_position` | `beginning` or `final`; defaults to `final` |
| `first_payment_date` | First contractual installment due date; distinct from receipt/disbursement |

## Financial::Loan::Installment

Canonical model for existing `financial_loan_installments` rows. Existing columns and
associations remain authoritative.

| Attribute | Rule |
|---|---|
| `due_date` | Contractual due date; direct edits affect only the selected installment |
| `manual_due_date` | True after direct edit; ordinary regeneration preserves it |
| planned transaction link | Its due-date fields change only after independent confirmation |
| payment/interest links | Historical records remain associated and financially unchanged |

An explicit reset can replace manual dates only for individually approved installments.

## Planned and Actual Records

Planned transaction due-date fields may be synchronized after consent and stale-state
validation. An actual entry's recorded/application date, amount, interest, account,
liability, and accounting history never change because an installment due date changes.

## Transient Impact Summary

The confirmation payload lists the selected installment, proposed due date, validation
context, affected manual dates, each linked planned record and its independent choice, and
each protected actual record. It is not a second persisted source of truth.

## Migration Notes

The namespace move requires no schema/data migration. Any schedule fields needed by the
transferred date requirements use reversible compatible migrations and do not rewrite
existing installment or actual-entry dates.
