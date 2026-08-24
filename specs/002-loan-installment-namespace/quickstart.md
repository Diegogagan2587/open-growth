# Quickstart: Loan Installment Domain and Schedule Management

Run the focused model, schedule, workflow, request, and UI tests after the namespace move.
The relevant paths include the namespaced installment model and tests, repayment terms,
amortization, loan controllers, installment workflow, and loan-view boundaries.

Verify application boot/autoload and confirm that `Financial::Loan::Installment` is the
only canonical model constant while `financial_loan_installments` remains unchanged.

Manually verify:

1. A loan received August 22 with a first payment due September 15 uses September 15 as
   installment one and labels the field clearly.
2. Beginning/final exceptional payments remain ordered and reconciled.
3. Editing one installment leaves neighboring dates unchanged.
4. A pending planned record is updated only when its individual summary choice is
   accepted.
5. A paid installment's due date can change while its actual date and financial history
   remain unchanged.
6. Ordinary regeneration preserves manual dates; selective reset changes only approved
   manual dates.
7. A stale confirmation fails without partial linked updates.
8. Existing rows and all loan workflows still read/write the same table and associations.
