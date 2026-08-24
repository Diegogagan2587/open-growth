# Implementation Plan: Loan Installment Domain and Schedule Management

**Branch**: `002-loan-installment-namespace` | **Date**: 2026-08-24 | **Spec**: [spec.md](./spec.md)

## Summary

Carry the existing loan-payment design into the namespaced model while preserving the
implemented different-payment position behavior and completing the clarified schedule
anchor, manual due-date, linked-planned-record, and protected-actual-record workflows.

The canonical model becomes `Financial::Loan::Installment` at
`app/models/financial/loan/installment.rb`; the table remains
`financial_loan_installments`. This is a domain refactor plus the transferred schedule
work, not a data migration or a change to accounting history.

## Design

- Keep repayment ordering in `RepaymentTerms` and schedule projection in
  `AmortizationSchedule`.
- Store `different_payment_amount`, `different_payment_position`, and
  `first_payment_date` on the loan configuration.
- Store `due_date`, `manual_due_date`, and existing planned/payment/interest links on the
  namespaced installment.
- Keep due dates, planned-record due dates, and actual entry dates distinct.
- Use one intention-revealing workflow for due-date impact calculation and atomic selected
  updates, with locks and stale-state rechecks.
- Preserve manual dates during ordinary regeneration; selective reset is explicit and
  per-installment.

## Affected Areas

- Model and associations: `Financial::Loan`, `Financial::Loan::Installment`, and callers.
- Repayment and schedule domain: `RepaymentTerms`, `AmortizationSchedule`, regeneration.
- Loan view/form and installment edit confirmation using existing Rails UI conventions.
- Planned transaction synchronization; actual payment and interest records remain history.
- Focused model, workflow, request, component/system, boot, and lint tests.

## Data Safety

No table, column, index, foreign-key, or financial-value migration is required for the
namespace change. Existing schedules and actual entries are preserved. Any schedule/date
change is atomic and applies only explicitly selected linked planned records.

## Deferred Scope

Extra-payment events and configurable interest-policy behavior remain documented in the
specification and require their own implementation slice if the existing domain does not
already support them.
