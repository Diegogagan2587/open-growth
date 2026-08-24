# Quickstart: Loan Payment Override Position

## Prerequisites

- Development dependencies installed.
- Test database available and current.
- An authenticated account with access to the loan simulation screen.

## Automated validation

Run the focused domain tests:

```bash
bin/rails test test/models/financial/loans/repayment_terms_test.rb \
  test/models/financial/loans/amortization_schedule_test.rb \
  test/models/financial/loan_test.rb
```

Run the relevant request and workflow tests:

```bash
bin/rails test test/controllers/financial/loans_controller_test.rb \
  test/services/financial/loans/repayment_workflows_test.rb
```

Run view linting when the form is changed:

```bash
npm run herb:lint
```

## Manual validation scenarios

1. Open a new loan simulation using payment amounts, enter a regular payment and a
   different payment, select `Beginning`, and submit.
   - Confirm the first generated payment uses the different amount.
   - Confirm later payments use the regular amount where balance rules allow.
   - Confirm the position and exceptional payment are clear in the schedule.
2. Edit the simulation, select `Final`, and regenerate the schedule.
   - Confirm the final payment uses the different amount.
   - Confirm existing final behavior remains unchanged.
3. Enter zero, a negative value, or an amount that cannot reconcile the loan.
   - Confirm an actionable validation message appears.
   - Confirm no inaccurate schedule is accepted.
4. Test a one-payment loan with each position.
   - Confirm the different payment is applied once, not twice.
5. Open an existing loan created before this change.
   - Confirm it is interpreted as a final-position different payment and its financial
     meaning is preserved.

See [data-model.md](./data-model.md) for persistence and domain invariants and
[contracts/loan-simulation-ui.md](./contracts/loan-simulation-ui.md) for the user-facing
contract.
