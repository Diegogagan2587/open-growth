# Feature decisions

This is the maintained home for product behavior and design decisions. Add new decisions here as features are built; keep generated Spec Kit artifacts in `specs/` focused on implementation workflow.

## Financial plans

### Planned expense source account

When editing a pending expense on a financial plan, users can change its source account. Opening the picker shows all active accounts in the household, including asset accounts and liabilities such as credit cards. The current account name is selected in the search field, so typing replaces it and filters the options; users choose a valid account from the results. Account ownership remains validated by the planned expense model.

This reflects that a planned expense may be paid from cash or debit, or charged to a credit card. The source account is the actual account that will fund or record the expense, not necessarily an asset account.

### Plan forecast and balance corrections

The plans list shows expected funding, planned consumption, each plan's net balance, and the global balance through each plan. Planned consumption includes balance-reducing planned transactions; a plan's net balance is its expected funding minus that consumption. The global balance is a running total of plan net balances ordered by plan date, and it includes only plans currently shown after filters. This lets users inspect how each plan changes the forecast in the current view.

On a plan's transaction table, each row shows cumulative consumption through that transaction and the remaining plan balance. This makes it easier to see when planned spending uses up expected funding. The move-up and move-down controls are stacked and aligned with the position number to save horizontal space. Reordering refreshes only the planned-transactions section so the updated order and balances appear without reloading the whole page.

Users can correct forecast drift by setting the actual global balance at a plan checkpoint. The checkpoint replaces the running global balance at that plan; subsequent plans continue accumulating from the corrected value. It does not rewrite the plan's own net balance or any actual ledger entries. This supports quick corrections for real expenses that were not associated with a plan, without requiring users to remember and retroactively attach every expense to the right plan.

The correction is exposed as a nested singleton HTTP resource and handled by its own controller. The plan owns the checkpoint-setting behavior, while the overview calculates the resulting running balance. No separate correction table is needed because only the current checkpoint is retained; an audit history can be added if that need emerges.

Keep one numeric correction mechanism: a checkpoint is easier to understand than overlapping adjustment types. If users need more context for corrections, an optional note can be considered later; it is not required for the forecast correction itself.

### Restoring a cancelled plan

Cancellation is reversible. The plan's cancellation resource creates a cancellation and destroys it to restore the plan. The plan stores whether it was a draft or active before cancellation, so restoring returns it to that state. Existing cancelled plans created before this behavior have no saved prior state and restore as drafts.
