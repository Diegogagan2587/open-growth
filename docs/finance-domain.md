# Finance domain

Open Budget plans future money and records actual personal money movements. The canonical flow is:

`RecurringTransaction → PlannedTransaction → Execution → Transaction → Account balances`

`Plan → FundingSource / PlannedTransaction → Receipt / Execution → Transaction → Account balances`

## Ubiquitous language

- **Account** (root model): the household ownership and membership boundary.
- **Financial Account**: a place where money is held or owed. Its `account_group` is either `asset` or `liability`.
- **Plan**: a dated collection of expected funding and intended transactions.
- **Funding Source**: one expected incoming deposit for one Plan.
- **Receipt**: the lifecycle event that fulfills one Funding Source by creating its one actual Transaction.
- **Planned Transaction**: an intended expense, transfer, or debt payment. It may be unassigned to a Plan.
- **Recurring Transaction**: an active or archived reusable definition for creating Planned Transaction occurrences. It stores cadence, routing defaults, and Plan budget treatment; existing occurrences are snapshots of those defaults.
- **Execution**: the lifecycle event that fulfills one Planned Transaction by creating its one actual Transaction.
- **Transaction**: an editable record of what actually happened. Transactions drive balances and actual reports.
- **Account Route**: the source and destination Financial Accounts that classify actual money movement as an inflow, outflow, liability charge, transfer, liability payment, or loan disbursement. A destination-only inflow defaults to income while explicit refund and adjustment meanings are preserved.
- **Reconciliation**: verification that a Transaction matches the bank. It is represented by `reconciled_at`, not by a separate table.
- **Loan Disbursement**: receipt of borrowed money. A Loan becomes active at this event.
- **Savings Goal**: a named target whose progress comes from actual Transactions created by its planned contributions.
- **Budget Allocation**: the amount assigned to one Category in one Budget Period.

## Lifecycle rules

One Funding Source has one Receipt. A differing amount closes it with variance; a late or early receipt of the expected amount is still received. Another expected deposit requires another Funding Source.

A Loan is simulated until its disbursement reaches the destination asset Financial Account. Activation and disbursement are one event. Removing a disbursement restores the simulation only while no repayment history exists.

Transactions are editable. Correcting amount, date, type, source, or destination clears reconciliation. Editing description, notes, category, or Plan assignment preserves it. Deleting a workflow-created Transaction restores the originating lifecycle atomically.

Recurring Transactions and Savings Goals are separate concepts. A recurrence describes repeated intent; a Savings Goal describes finite progress toward a target. `budget_consuming` is planning policy and does not change whether an actual movement is an expense, payment, or transfer.

Account Route owns the routing vocabulary used by actual, Planned, and Recurring Transactions. Actual routes are complete and cover incoming and outgoing movement. Planned and Recurring Transactions remain outgoing intentions and may omit their source until execution; Funding Sources model planned incoming money.

## HTTP organization

Finance uses `/finance` URLs and the `Financial` Ruby namespace. Nested lifecycle controllers are organized with `scope module:` without adding controller folders to URLs. HTTP resources do not imply tables: Reconciliation, Receipt, Execution, Closure, Cancellation, Archive, Disbursement, and Amortization Schedule are focused interfaces over their owning entities.

Every Finance lookup starts from `Current.account` or an association already scoped through it.
