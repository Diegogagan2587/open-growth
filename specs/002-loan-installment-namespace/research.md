# Research: Loan Installment Domain and Schedule Management

## Decision 1: Namespace the persisted installment model

Use `Financial::Loan::Installment` in `app/models/financial/loan/installment.rb`. Keep the
table `financial_loan_installments`; Rails naming changes do not justify a data migration
or an undocumented runtime alias.

## Decision 2: Use neutral different-payment names

Persist `different_payment_position` with `beginning` and `final`, defaulting to `final`,
and use `different_payment_amount` for the one exceptional amount. Existing final-payment
records retain their meaning and the amount is not rewritten.

## Decision 3: Anchor schedules by first payment date

`first_payment_date` is the first contractual installment due date, not loan receipt or
disbursement. Existing schedules remain unchanged until explicit regeneration.

## Decision 4: Keep date concepts separate

An installment contractual due date, a planned transaction's due-date fields, and an actual
entry's application/recorded date represent different facts. Due-date correction may
update a confirmed planned record, but never mutates actual payment dates or accounting
values.

## Decision 5: Use one impact summary with independent choices

One summary is easier to audit than a popup cascade and still lets the user approve or
decline each linked planned update and each manual-date reset independently.

## Decision 6: Preserve manual dates by default; reset selectively

Direct edits mark `manual_due_date`. Ordinary regeneration preserves those dates. An
explicit reset presents each affected manual date and applies only approved replacements.

## Decision 7: Re-check linked state

Lock the relevant installment and re-check selected planned records before applying a
confirmation. Stale state aborts the selected linked update without partial changes.

## Deferred Decision

Extra-payment events and interest-allocation policies remain specified but are not implied
to be delivered by the namespace refactor; they need a dedicated implementation slice.
