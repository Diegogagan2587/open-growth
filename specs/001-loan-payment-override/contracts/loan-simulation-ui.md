# Loan Simulation UI Contract

## Payment terms input

When the repayment basis is payment amounts, the simulation form exposes:

- Regular payment: the default amount for non-exceptional payments.
- Different payment: optional positive amount for one exceptional payment.
- Different payment position: `Beginning` or `Final`, submitted as `different_payment_position`.

The position selector is presented with the different-payment input and has a clear
label. If no different payment is entered, the position has no schedule effect.

## Generated schedule contract

For a valid simulation:

- `Beginning` places the different payment at installment 1.
- `Final` places the different payment at the last configured installment.
- Other installments use the regular payment, subject to existing balance and rounding
  rules.
- A one-installment schedule applies the different payment once.
- The displayed schedule identifies the exceptional payment position and remains
  financially reconciled.

For an invalid simulation, the form remains available with an actionable validation
message and no accepted inaccurate schedule is presented.

## Compatibility contract

Existing loans with a different payment continue to behave as final-position loans
unless the user explicitly changes the position.
