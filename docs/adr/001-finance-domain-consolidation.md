# ADR 001: Consolidate the Finance domain around plans and transactions

Status: accepted

## Context

Finance had two overlapping models. `Financial::Plan` inherited from `IncomeEvent`, `Financial::PlannedTransaction` inherited from `PlannedExpense`, actual movements were called Entries, and assets and liabilities used separate routing interfaces. This mixed intentions, workflows, and actual money tracking.

## Decision

Use independent tables for Plans and Planned Transactions; one Financial Account table classified as asset or liability; and Transaction as the canonical actual movement. Model one-to-one lifecycle changes as Receipt, Execution, Reconciliation, and Loan Disbursement HTTP resources. Keep root `Account` as the household boundary.

Transactions remain editable because the product captures frequent small expenses and later bank-review corrections. Reconciliation means bank verification, not immutability.

Legacy tables, columns, model adapters, and GET redirects may remain during the audit and rollback window. New writes use only the canonical interfaces. Contract migrations remove compatibility state only after count, total, routing, balance, ordering, and relationship parity is verified in production.

Recurring Transactions and Savings Goals remain independent entities. A Recurring Transaction creates snapshot Planned Transaction occurrences and may explicitly reserve Plan budget even when its eventual actual Transaction is a budget-neutral transfer. A Savings Goal retains finite target progress and does not replace the recurrence catalog.

## Consequences

Domain concepts have independent lifecycles and account-scoped associations. Database uniqueness enforces one Receipt per Funding Source, one Transaction per Execution, and one Disbursement per Loan. Focused controllers add files but reduce controller responsibility. Assets and liabilities share routing while retaining explicit opposite balance invariants.

The migration is intentionally expand/backfill/switch/contract. Until contract, adapters such as `Financial::Entry`, `Financial::Asset`, and `Financial::Liability` exist only for compatibility and must not receive new feature work.
