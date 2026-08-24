# Loan Simulation and Installment Date UI Contract

## Repayment Inputs

The loan form exposes the neutral different-payment amount and a `Beginning`/`Final`
`different_payment_position` selector. It also labels the schedule anchor `First payment
date` and explains that it is the first repayment due date, not receipt/disbursement.

## Schedule

The first installment uses `first_payment_date`; later derived dates follow frequency.
The exceptional amount appears once in the selected position. Existing schedules retain
their dates until explicit regeneration.

## Due-Date Editing

From the loan view, an installment edit shows one accessible impact summary containing the
current/proposed due date, validation context, each affected manual date, each linked
planned record with an independent update choice, and each actual payment explicitly
marked as date/history-preserved.

Cancel changes nothing. Confirmed changes affect only the selected installment plus linked
planned/manual records individually approved by the user. Actual payment/application dates
are never selectable for automatic mutation. Invalid or stale state produces actionable
feedback and no partial linked update.
